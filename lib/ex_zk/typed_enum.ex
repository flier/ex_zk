defmodule ExZk.TypedEnum do
  @moduledoc """
  Provides `defenum/2` macro for defining a typed Enum type.

  This module can also be `use`d to create a typed Enum like:

      defmodule CustomEnum do
        use ExZk.TypedEnum, ready: 0, set: 1, go: 2
      end
  """

  @doc """
  Defines a typed enum.

  For second argument, it accepts either a list of strings or a keyword list with keyword
  values that are either strings or integers. Below are examples of a valid argument:
      [registered: 0, active: 1, inactive: 2, archived: 3]
      [registered: "registered", active: "active", inactive: "inactive", archived: "archived"]
      ["registered", "active", "inactive", "archived"]

  It can be used with fields. For example:

      import ExZk.TypedEnum
      defenum StatusEnum, registered: 0, active: 1, inactive: 2, archived: 3

  """

  defmacro __using__(opts) do
    quote do
      use ExZk.TypedEnum.Use, unquote(opts)
    end
  end

  defmacro defenum(module, enum) do
    quote do
      enum = Macro.escape(unquote(enum))

      enum =
        case enum do
          [h | _] when is_binary(h) ->
            enum |> Enum.map(&{String.to_atom(&1), &1})

          [h | _] when is_atom(h) ->
            enum |> Enum.map(&{&1, Atom.to_string(&1)})

          _ ->
            if Keyword.keyword?(enum) do
              enum
            else
              raise "Enum must be a keyword list or a list of atoms/strings"
            end
        end

      defmodule unquote(module) do
        use ExZk.TypedEnum.Use, enum
      end
    end
  end
end

defmodule ExZk.TypedEnum.Use do
  @moduledoc false

  alias ExZk.TypedEnum.Typespec

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      typespec = Typespec.make(Keyword.keys(opts))

      @type t :: unquote(typespec)

      keys = Keyword.keys(opts)
      key_names = Enum.map(keys, &Atom.to_string/1)
      @valid_values Enum.uniq(keys ++ key_names ++ Keyword.values(opts))

      {_key, value} = opts |> hd()

      type =
        if is_integer(value) do
          :integer
        else
          :string
        end

      def type, do: unquote(type)

      for {key, value} <- opts, k <- Enum.uniq([key, value, Atom.to_string(key)]) do
        def cast(unquote(k)), do: {:ok, unquote(key)}
      end

      def cast(_other), do: :error

      for {key, value} <- opts, k <- Enum.uniq([key, value, Atom.to_string(key)]) do
        def value(unquote(k)), do: {:ok, unquote(value)}
      end

      def value(term) do
        msg =
          "Value `#{inspect(term)}` is not a valid enum for `#{inspect(__MODULE__)}`. " <>
            "Valid enums are `#{inspect(__valid_values__())}`"

        raise RuntimeError, message: msg
      end

      def embed_as(_), do: :self

      def equal?(term1, term2), do: term1 == term2

      for {key, _value} <- opts do
        def match?(unquote(key)), do: true
      end

      def match?(_), do: false

      for {key, value} <- opts do
        def load(unquote(value)), do: {:ok, unquote(key)}
      end

      def valid_value?(value) do
        Enum.member?(@valid_values, value)
      end

      # # Reflection
      def __enum_map__(), do: unquote(opts)
      def __valid_values__(), do: @valid_values
    end
  end
end

defmodule ExZk.TypedEnum.Typespec do
  @moduledoc "Helper for generating enum typespecs"

  def make(enums) do
    enums
    |> Enum.reverse()
    |> Enum.reduce(fn
      a, acc when is_atom(a) or is_binary(a) -> add_type(a, acc)
      {a, _}, acc when is_atom(a) -> add_type(a, acc)
      _, acc -> acc
    end)
  end

  defp add_type(type, acc), do: {:|, [], [type, acc]}
end

defmodule ExZk.TypedEnum.TestModule do
  @moduledoc """
  Sample enum-containing module for testing type generation. Types aren't
  generated for dynamically generated modules that eunit uses, so we have to
  prepare this module in advance
  """

  import ExZk.TypedEnum

  defenum(StatusEnum, registered: 0, active: 1, inactive: 2, archived: 3)

  defenum(StatusEnum2, [:registered, :active, :inactive, :archived])

  defenum(StatusEnum3, ["registered", "active", "inactive", "archived"])
end
