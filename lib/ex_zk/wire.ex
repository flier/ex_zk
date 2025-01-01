defmodule ExZk.Wire do
  @type type() ::
          :byte
          | :boolean
          | :int
          | :long
          | :float
          | :double
          | :ustring
          | :buffer
          | term()
          | {:vector, type()}

  ####
  ## Protocols
  ##

  defprotocol Pack do
    @spec pack(value :: any()) :: binary()
    @doc "Pack a value into a binary"
    def pack(value)
  end

  ####
  ## Public API
  ##

  @doc """
  Pack a value into a binary

  ## Examples

      iex> import ExZk.Wire
      iex> pack(nil)
      <<>>
      iex> pack({:boolean, nil})
      <<>>
      iex> pack({:boolean, true})
      <<1>>
      iex> pack({:boolean, false})
      <<0>>
      iex> pack({:byte, 42})
      <<42>>
      iex> pack({:byte, -2})
      <<254>>
      iex> pack({:int, 42})
      <<0, 0, 0, 42>>
      iex> pack({:int, -2})
      <<0xFF, 0xFF, 0xFF, 0xFE>>
      iex> pack({:long, 42})
      <<0, 0, 0, 0, 0, 0, 0, 42>>
      iex> pack({:long, -2})
      <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE>>
      iex> pack({:float, 3.14})
      <<64, 72, 245, 195>>
      iex> pack({:double, 3.14})
      <<64, 9, 30, 184, 81, 235, 133, 31>>
      iex> pack({:ustring, "hello"})
      <<0, 0, 0, 5, 104, 101, 108, 108, 111>>
      iex> pack({:ustring, ""})
      <<0, 0, 0, 0>>
      iex> pack({:buffer, "hello"})
      <<0, 0, 0, 5, 104, 101, 108, 108, 111>>
      iex> pack({:buffer, <<>>})
      <<0xff, 0xff, 0xff, 0xff>>
      iex> pack({{:vector, :int}, [1, 2, 3]})
      <<0, 0, 0, 3, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3>>
      iex> pack({{:vector, :int}, []})
      <<0xFF, 0xFF, 0xFF, 0xFF>>
      iex> pack([{:int, 42}, {:ustring, "hello"}])
      <<0, 0, 0, 42, 0, 0, 0, 5, 104, 101, 108, 108, 111>>
      iex> pack(%ExZk.Data.Id{scheme: "zk", id: "test"})
      <<0, 0, 0, 2, ?z, ?k, 0, 0, 0, 4, ?t, ?e, ?s, ?t>>

  """
  @spec pack({type(), value :: any()} | [{type(), value :: any()}] | term()) :: binary()
  def pack(nil), do: <<>>
  def pack({_type, nil}), do: <<>>
  def pack({:boolean, b}) when is_boolean(b), do: if(b, do: <<1::8>>, else: <<0::8>>)
  def pack({:byte, n}) when is_integer(n), do: <<n::integer-signed-size(8)>>
  def pack({:int, n}) when is_integer(n), do: <<n::integer-signed-size(32)>>
  def pack({:long, n}) when is_integer(n), do: <<n::integer-signed-size(64)>>
  def pack({:float, f}) when is_float(f), do: <<f::float-size(32)>>
  def pack({:double, f}) when is_float(f), do: <<f::float-size(64)>>
  def pack({:ustring, s}) when is_binary(s), do: <<byte_size(s)::32, s::binary>>
  def pack({:buffer, <<>>}), do: <<-1::32>>
  def pack({:buffer, b}) when is_binary(b), do: <<byte_size(b)::32, b::binary>>
  def pack({{:vector, _type}, []}), do: <<-1::32>>

  def pack({{:vector, type}, v}) when is_list(v) do
    v |> Stream.map(&pack({type, &1})) |> Enum.reduce(<<length(v)::32>>, &(&2 <> &1))
  end

  def pack({mod, value}) do
    if Pack.impl_for(value) do
      Pack.pack(value)
    else
      mod.pack(value)
    end
  end

  def pack(values) when is_list(values), do: Enum.map_join(values, &pack(&1))
  def pack(value) when is_struct(value), do: Pack.pack(value)

  @doc """
  Unpack a binary into a value

  ## Examples

      iex> import ExZk.Wire
      iex> unpack(<<1>>, :boolean)
      {:ok, true, <<>>}
      iex> unpack(<<0>>, :boolean)
      {:ok, false, <<>>}
      iex> unpack(<<42>>, :byte)
      {:ok, 42, <<>>}
      iex> unpack(<<0, 0, 0, 42>>, :int)
      {:ok, 42, <<>>}
      iex> unpack(<<0, 0, 0, 0, 0, 0, 0, 42>>, :long)
      {:ok, 42, <<>>}
      iex> {:ok, n, <<>>} = unpack(<<64, 72, 245, 195>>, :float)
      iex> Float.round(n, 3)
      3.14
      iex> {:ok, n, <<>>} = unpack(<<64, 9, 30, 184, 81, 235, 133, 31>>, :double)
      iex> Float.round(n, 3)
      3.14
      iex> unpack(<<0, 0, 0, 5, 104, 101, 108, 108, 111>>, :ustring)
      {:ok, "hello", <<>>}
      iex> unpack(<<0, 0, 0, 5, 104, 101, 108, 108, 111>>, :buffer)
      {:ok, "hello", <<>>}
      iex> unpack(<<0xff, 0xff, 0xff, 0xff>>, :buffer)
      {:ok, "", <<>>}
      iex> unpack(<<0, 0, 0, 0>>, {:vector, :int})
      {:ok, [], <<>>}
      iex> unpack(<<0xff, 0xff, 0xff, 0xff>>, {:vector, :int})
      {:ok, [], <<>>}
      iex> unpack(<<0, 0, 0, 3, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3>>, {:vector, :int})
      {:ok, [1, 2, 3], <<>>}
      iex> unpack(<<>>, :boolean)
      {:error, :nomatch}
      iex> unpack(<<0, 0, 0, 3, 0, 0, 0, 1, 0, 0, 0, 2>>, {:vector, :int})
      {:error, :nomatch}
      iex> unpack(<<0, 0, 0, 42, 0, 0, 0, 5, 104, 101, 108, 108, 111>>, [:int, :ustring])
      {:ok, [42, "hello"], <<>>}
      iex> unpack(<<0, 0, 0, 42, 0, 0, 0, 5, 104, 101, 108, 108, 111>>, age: :int, name: :ustring)
      {:ok, [age: 42, name: "hello"], <<>>}
      iex> unpack(<<0, 0, 0, 42, 0, 0, 0, 5, 104, 101, 108, 108, 111>>, [:int, :ustring, :buffer])
      {:error, :nomatch}

  """
  @spec unpack(buf :: binary(), type() | [type()] | Keyword.t()) ::
          {:ok, value :: any(), rest :: binary()} | {:error, :nomatch}
  def unpack(<<>>, _type), do: {:error, :nomatch}

  def unpack(<<b::8, rest::binary>>, :boolean), do: {:ok, b != 0, rest}
  def unpack(<<n::integer-signed-size(8), rest::binary>>, :byte), do: {:ok, n, rest}
  def unpack(<<n::integer-signed-size(32), rest::binary>>, :int), do: {:ok, n, rest}
  def unpack(<<n::integer-signed-size(64), rest::binary>>, :long), do: {:ok, n, rest}
  def unpack(<<f::float-size(32), rest::binary>>, :float), do: {:ok, f, rest}
  def unpack(<<f::float-size(64), rest::binary>>, :double), do: {:ok, f, rest}
  def unpack(<<0xFF, 0xFF, 0xFF, 0xFF, rest::binary>>, :buffer), do: {:ok, "", rest}

  def unpack(<<len::32, s::binary-size(len), rest::binary>>, type)
      when type in [:ustring, :buffer],
      do: {:ok, s, rest}

  def unpack(_buf, type)
      when type in [:boolean, :byte, :int, :long, :float, :double, :ustring, :buffer],
      do: {:error, :nomatch}

  def unpack(<<0, 0, 0, 0, rest::binary>>, {:vector, _type}), do: {:ok, [], rest}
  def unpack(<<0xFF, 0xFF, 0xFF, 0xFF, rest::binary>>, {:vector, _type}), do: {:ok, [], rest}

  def unpack(<<len::32, rest::binary>>, {:vector, type}) do
    with {:ok, l, rest} <-
           1..len |> Enum.reduce_while({:ok, [], rest}, &unpack_vector(&1, &2, type)) do
      {:ok, l |> Enum.reverse(), rest}
    end
  end

  def unpack(buf, mod) when is_binary(buf) and is_atom(mod), do: mod.unpack(buf)

  def unpack(buf, type) when is_binary(buf) and is_binary(type) do
    mod = type |> String.to_atom()
    mod.unpack(buf)
  end

  def unpack(buf, types) when is_binary(buf) and is_list(types) do
    with {:ok, l, rest} <- types |> Enum.reduce_while({:ok, [], buf}, &unpack_type(&1, &2)) do
      {:ok, l |> Enum.reverse(), rest}
    end
  end

  ####
  ## Private methods
  ##

  defp unpack_vector(_, {_acc, []}, _type), do: {:halt, {[], {:error, :nomatch}}}

  defp unpack_vector(_, {:ok, acc, buf}, type) do
    case unpack(buf, type) do
      {:ok, v, rest} -> {:cont, {:ok, [v | acc], rest}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp unpack_type({name, _type}, {acc, ""}) do
    {:cont, {:ok, [{name, nil} | acc], ""}}
  end

  defp unpack_type({name, type}, {:ok, acc, buf}) do
    case unpack(buf, type) do
      {:ok, v, rest} -> {:cont, {:ok, [{name, v} | acc], rest}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp unpack_type(type, {:ok, acc, buf}) do
    case unpack(buf, type) do
      {:ok, v, rest} -> {:cont, {:ok, [v | acc], rest}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end
end
