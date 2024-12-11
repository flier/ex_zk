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

  defprotocol Pack do
    @spec pack(value :: any()) :: binary()
    @doc "Pack a value into a binary"
    def pack(value)
  end

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
      <<0, 0, 0, 0>>
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
  def pack({:buffer, b}) when is_binary(b), do: <<byte_size(b)::32, b::binary>>
  def pack({{:vector, _type}, []}), do: <<-1::32>>

  def pack({{:vector, type}, v}) when is_list(v) do
    v |> Enum.map(&pack({type, &1})) |> Enum.reduce(<<length(v)::32>>, &(&2 <> &1))
  end

  def pack({mod, value}) do
    if Pack.impl_for(value) do
      Pack.pack(value)
    else
      apply(mod, :pack, [value])
    end
  end

  def pack(values) when is_list(values) do
    Enum.reduce(values, <<>>, fn e, buf -> buf <> pack(e) end)
  end

  def pack(value) when is_struct(value), do: Pack.pack(value)

  @doc """
  Unpack a binary into a value

  ## Examples

      iex> import ExZk.Wire
      iex> unpack(:boolean, <<1>>)
      {:ok, true, <<>>}
      iex> unpack(:boolean, <<0>>)
      {:ok, false, <<>>}
      iex> unpack(:byte, <<42>>)
      {:ok, 42, <<>>}
      iex> unpack(:int, <<0, 0, 0, 42>>)
      {:ok, 42, <<>>}
      iex> unpack(:long, <<0, 0, 0, 0, 0, 0, 0, 42>>)
      {:ok, 42, <<>>}
      iex> {:ok, n, <<>>} = unpack(:float, <<64, 72, 245, 195>>)
      iex> Float.round(n, 3)
      3.14
      iex> {:ok, n, <<>>} = unpack(:double, <<64, 9, 30, 184, 81, 235, 133, 31>>)
      iex> Float.round(n, 3)
      3.14
      iex> unpack(:ustring, <<0, 0, 0, 5, 104, 101, 108, 108, 111>>)
      {:ok, "hello", <<>>}
      iex> unpack(:buffer, <<0, 0, 0, 5, 104, 101, 108, 108, 111>>)
      {:ok, "hello", <<>>}
      iex> unpack({:vector, :int}, <<0xff, 0xff, 0xff, 0xff>>)
      {:ok, [], <<>>}
      iex> unpack({:vector, :int}, <<0, 0, 0, 3, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3>>)
      {:ok, [1, 2, 3], <<>>}
      iex> unpack(:boolean, <<>>)
      {:error, :nomatch}
      iex> unpack({:vector, :int}, <<0, 0, 0, 3, 0, 0, 0, 1, 0, 0, 0, 2>>)
      {:error, :nomatch}
      iex> unpack([:int, :ustring], <<0, 0, 0, 42, 0, 0, 0, 5, 104, 101, 108, 108, 111>>)
      {:ok, [42, "hello"], <<>>}
      iex> unpack([:int, :ustring, :buffer], <<0, 0, 0, 42, 0, 0, 0, 5, 104, 101, 108, 108, 111>>)
      {:error, :nomatch}

  """
  @spec unpack(type(), buf :: binary()) ::
          {:ok, value :: any(), rest :: binary()} | {:error, :nomatch}
  def unpack(_type, <<>>), do: {:error, :nomatch}

  def unpack(:boolean, buf) when is_binary(buf) do
    case buf do
      <<b::8, rest::binary>> -> {:ok, b != 0, rest}
      _ -> {:error, :nomatch}
    end
  end

  def unpack(:byte, buf) when is_binary(buf) do
    case buf do
      <<n::integer-signed-size(8), rest::binary>> -> {:ok, n, rest}
      _ -> {:error, :nomatch}
    end
  end

  def unpack(:int, buf) when is_binary(buf) do
    case buf do
      <<n::integer-signed-size(32), rest::binary>> -> {:ok, n, rest}
      _ -> {:error, :nomatch}
    end
  end

  def unpack(:long, buf) when is_binary(buf) do
    case buf do
      <<n::integer-signed-size(64), rest::binary>> -> {:ok, n, rest}
      _ -> {:error, :nomatch}
    end
  end

  def unpack(:float, buf) when is_binary(buf) do
    case buf do
      <<f::float-size(32), rest::binary>> -> {:ok, f, rest}
      _ -> {:error, :nomatch}
    end
  end

  def unpack(:double, buf) when is_binary(buf) do
    case buf do
      <<f::float-size(64), rest::binary>> -> {:ok, f, rest}
      _ -> {:error, :nomatch}
    end
  end

  def unpack(:ustring, buf) when is_binary(buf) do
    case buf do
      <<len::32, s::binary-size(len), rest::binary>> -> {:ok, s, rest}
      _ -> {:error, :nomatch}
    end
  end

  def unpack(:buffer, buf) when is_binary(buf) do
    case buf do
      <<len::32, s::binary-size(len), rest::binary>> -> {:ok, s, rest}
      _ -> {:error, :nomatch}
    end
  end

  def unpack({:vector, type}, buf) when is_binary(buf) do
    case buf do
      <<0xFF, 0xFF, 0xFF, 0xFF, rest::binary>> ->
        {:ok, [], rest}

      <<len::32, rest::binary>> ->
        case 1..len
             |> Enum.reduce_while({rest, []}, fn _, {buf, acc} ->
               case buf do
                 [] ->
                   {:halt, {[], {:error, :nomatch}}}

                 _ ->
                   case unpack(type, buf) do
                     {:ok, v, rest} -> {:cont, {rest, [v | acc]}}
                     {:error, reason} -> {:halt, {buf, {:error, reason}}}
                   end
               end
             end) do
          {rest, l} when is_list(l) -> {:ok, l |> Enum.reverse(), rest}
          {_, {:error, reason}} -> {:error, reason}
        end
    end
  end

  def unpack(mod, buf) when is_atom(mod) and is_binary(buf), do: apply(mod, :unpack, [buf])

  def unpack(type, buf) when is_binary(type) and is_binary(buf) do
    apply(type |> String.to_atom(), :unpack, [buf])
  end

  def unpack(types, buf) when is_list(types) and is_binary(buf) do
    case types
         |> Enum.reduce_while({:ok, [], buf}, fn type, {:ok, acc, buf} ->
           case unpack(type, buf) do
             {:ok, v, rest} -> {:cont, {:ok, [v | acc], rest}}
             {:error, reason} -> {:halt, {:error, reason}}
           end
         end) do
      {:ok, l, rest} -> {:ok, Enum.reverse(l), rest}
      {:error, reason} -> {:error, reason}
    end
  end
end
