defmodule ExZk.Jute do
  defmodule Module do
    alias ExZk.Jute.Class

    defstruct [:name, :classes]

    @type t() :: %__MODULE__{
            name: String.t(),
            classes: [Class.t()]
          }

    def new(fields) do
      struct!(__MODULE__, fields)
    end
  end

  defmodule Class do
    alias ExZk.Jute.Field

    defstruct [:name, :fields, doc: nil]

    @type t() :: %__MODULE__{
            name: String.t(),
            fields: [Field.t()],
            doc: String.t() | nil
          }

    def new(fields) do
      struct!(__MODULE__, fields)
    end
  end

  defmodule Field do
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

    defstruct [:name, :type, doc: nil]

    @type t() :: %__MODULE__{
            name: String.t(),
            type: String.t(),
            doc: String.t() | nil
          }

    def new(fields) do
      struct!(__MODULE__, fields)
    end
  end

  defmodule Parser do
    import NimbleParsec

    whitespace = ascii_char([?\s, ?\t, ?\n, ?\r])

    ws0 = repeat(whitespace)
    ws1 = times(whitespace, min: 1)

    lbrace = ascii_char([?{])
    rbrace = ascii_char([?}])
    lt = ascii_char([?<])
    rt = ascii_char([?>])
    semi = ascii_char([?;])
    comma = ascii_char([?,])

    eol = choice([string("\r\n"), ascii_char([?\n, ?\r]), eos()])

    defcombinatorp(
      :skip,
      repeat(ignore(choice([whitespace, parsec(:line_comment), parsec(:block_comment)])))
    )

    @doc """
    Parse a block comment

    ## Example

        iex> ExZk.Jute.Parser.block_comment("/* comment */")
        {:ok, ~c" comment ", "", %{}, {1, 0}, 13}

        iex> ExZk.Jute.Parser.block_comment("/**/")
        {:ok, [], "", %{}, {1, 0}, 4}

        iex> ExZk.Jute.Parser.block_comment(\"""
        ...>/* This is a
        ...> multiline
        ...> comment */
        ...>\""")
        {:ok, ~c" This is a\\n multiline\\n comment ", "\\n", %{}, {3, 24}, 35}
    """
    defparsec(
      :block_comment,
      ignore(string("/*"))
      |> repeat(lookahead_not(string("*/")) |> utf8_char([]))
      |> ignore(string("*/"))
    )

    @doc ~S"""
    Parse a line comment

    ## Example

        iex> ExZk.Jute.Parser.line_comment("// comment")
        {:ok, ["comment"], "", %{}, {1, 0}, 10}

        iex> ExZk.Jute.Parser.line_comment("// comment\n")
        {:ok, ["comment"], "", %{}, {2, 11}, 11}

        iex> ExZk.Jute.Parser.line_comment("// comment\ntest")
        {:ok, ["comment"], "test", %{}, {2, 11}, 11}

    """
    defparsec(
      :line_comment,
      ignore(string("//"))
      |> ignore(ws0)
      |> utf8_string([{:not, ?\n}, {:not, ?\r}], min: 0)
      |> ignore(eol)
    )

    defcombinatorp(
      :ident,
      concat(
        ascii_char([?a..?z, ?A..?Z]),
        repeat(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
      )
    )

    defcombinatorp(:name, parsec(:ident) |> tag(:name))

    defcombinatorp(
      :module_name,
      parsec(:ident)
      |> concat(repeat(ascii_char([?.]) |> parsec(:ident)))
      |> wrap()
    )

    @doc ~S"""
    Parse a Jute file

    ## Example

        iex> ExZk.Jute.Parser.parse_file(\"""
        ...>/* some comment */
        ...>module A {}
        ...>module B {}
        ...>\""")
        {:ok, [
          %ExZk.Jute.Module{classes: [], name: ~c"A"},
          %ExZk.Jute.Module{classes: [], name: ~c"B"}
        ], "\n", %{}, {3, 31}, 42}

        iex> ExZk.Jute.Parser.parse_file(\"""
        ...>module A {
        ...>  class Id {
        ...>    ustring scheme;
        ...>    ustring id;
        ...>  }
        ...>}
        ...>module B {
        ...>  class ACL {
        ...>    int perms;
        ...>    Id id;
        ...>  }
        ...>}
        ...>\""")
        {:ok, [
          %ExZk.Jute.Module{
            classes: [
              %ExZk.Jute.Class{
                name: ~c"Id",
                fields: [
                  %ExZk.Jute.Field{name: ~c"scheme", type: :ustring},
                  %ExZk.Jute.Field{name: ~c"id", type: :ustring}
                ],
                doc: nil
              },
            ],
            name: ~c"A"
          },
          %ExZk.Jute.Module{
            classes: [
              %ExZk.Jute.Class{
                name: ~c"ACL",
                fields: [
                  %ExZk.Jute.Field{name: ~c"perms", type: :int},
                  %ExZk.Jute.Field{name: ~c"id", type: ~c"Id"}
                ],
                doc: nil
              },
            ],
            name: ~c"B"
          },
        ], "\n", %{}, {12, 121}, 122}
    """
    defparsec(:parse_file, repeat(parsec(:parse_module)))

    @doc ~S"""
    Parse a Jute module

    ## Example

        iex> ExZk.Jute.Parser.parse_module("module A {}")
        {:ok, [%ExZk.Jute.Module{classes: [], name: ~c"A"}], "", %{}, {1, 0}, 11}

        iex> ExZk.Jute.Parser.parse_module(\"""
        ...>module org.apache.zookeeper.data {
        ...>  class Id {
        ...>    ustring scheme;
        ...>    ustring id;
        ...>  }
        ...>  class ACL {
        ...>    int perms;
        ...>    Id id;
        ...>  }
        ...>}
        ...>\""")
        {:ok, [%ExZk.Jute.Module{
          classes: [
            %ExZk.Jute.Class{
              name: ~c"Id",
              fields: [
                %ExZk.Jute.Field{name: ~c"scheme", type: :ustring, doc: nil},
                %ExZk.Jute.Field{name: ~c"id", type: :ustring, doc: nil}
              ],
              doc: nil},
            %ExZk.Jute.Class{
              name: ~c"ACL",
              fields: [
                %ExZk.Jute.Field{name: ~c"perms", type: :int, doc: nil},
                %ExZk.Jute.Field{name: ~c"id", type: ~c"Id", doc: nil}
              ],
              doc: nil}
          ],
          name: ~c"org.apache.zookeeper.data"
        }], "\n", %{}, {10, 132}, 133}
    """

    defparsec(
      :parse_module,
      parsec(:skip)
      |> ignore(string("module"))
      |> ignore(ws1)
      |> (parsec(:module_name) |> unwrap_and_tag(:name))
      |> parsec(:skip)
      |> ignore(lbrace)
      |> parsec(:skip)
      |> parsec(:classes)
      |> parsec(:skip)
      |> ignore(rbrace)
      |> reduce({ExZk.Jute.Module, :new, []})
    )

    defcombinatorp(:classes, repeat(parsec(:parse_class)) |> tag(:classes))

    @doc ~S"""
    Parse a Jute class

    ## Example

        iex> ExZk.Jute.Parser.parse_class("class A {}")
        {:ok, [%ExZk.Jute.Class{name: ~c"A", fields: [], doc: nil}], "", %{}, {1, 0}, 10}

        iex> ExZk.Jute.Parser.parse_class("class A { long a; }")
        {:ok, [%ExZk.Jute.Class{name: ~c"A", fields: [%ExZk.Jute.Field{name: ~c"a", type: :long, doc: nil}], doc: nil}], "", %{}, {1, 0}, 19}

        iex> ExZk.Jute.Parser.parse_class(\"""
        ...>// information shared with the client
        ...>class Stat {
        ...>}
        ...>\""")
        {:ok, [%ExZk.Jute.Class{name: ~c"Stat", fields: [], doc: "information shared with the client"}], "\n", %{}, {3, 51}, 52}

        iex> ExZk.Jute.Parser.parse_class(\"""
        ...>class ACL {
        ...>int perms;
        ...>Id id;
        ...>}
        ...>\""")
        {:ok, [%ExZk.Jute.Class{name: ~c"ACL", fields: [
          %ExZk.Jute.Field{doc: nil, name: ~c"perms", type: :int},
          %ExZk.Jute.Field{name: ~c"id", type: ~c"Id", doc: nil}
        ], doc: nil}], "\n", %{}, {4, 30}, 31}
    """
    defparsec(
      :parse_class,
      ignore(ws0)
      |> optional(parsec(:line_comment) |> unwrap_and_tag(:doc))
      |> parsec(:skip)
      |> ignore(string("class"))
      |> parsec(:skip)
      |> parsec(:name)
      |> parsec(:skip)
      |> ignore(lbrace)
      |> parsec(:skip)
      |> parsec(:fields)
      |> parsec(:skip)
      |> ignore(rbrace)
      |> reduce({ExZk.Jute.Class, :new, []})
    )

    defcombinatorp(:fields, repeat(parsec(:parse_field)) |> tag(:fields))

    @doc ~S"""
    Parse a Jute field

    ## Example
        iex> ExZk.Jute.Parser.parse_field("long czxid;      // created zxid")
        {:ok, [%ExZk.Jute.Field{doc: "created zxid", name: ~c"czxid", type: :long}], "", %{}, {1, 0}, 32}

        iex> ExZk.Jute.Parser.parse_field("vector<org.apache.zookeeper.data.ACL> acl;")
        {:ok, [%ExZk.Jute.Field{doc: nil, name: ~c"acl", type: {:vector, ~c"org.apache.zookeeper.data.ACL"}}], "", %{}, {1, 0}, 42}

    """
    defparsec(
      :parse_field,
      parsec(:skip)
      |> parsec(:parse_type)
      |> ignore(ws0)
      |> parsec(:name)
      |> ignore(semi)
      |> ignore(ws0)
      |> concat(optional(parsec(:line_comment) |> unwrap_and_tag(:doc)))
      |> reduce({ExZk.Jute.Field, :new, []})
    )

    @doc """
    Parse a Jute type

    ## Example

        iex> ExZk.Jute.Parser.parse_type("byte")
        {:ok, [type: :byte], "", %{}, {1, 0}, 4}

        iex> ExZk.Jute.Parser.parse_type("boolean")
        {:ok, [type: :boolean], "", %{}, {1, 0}, 7}

        iex> ExZk.Jute.Parser.parse_type("int")
        {:ok, [type: :int], "", %{}, {1, 0}, 3}

        iex> ExZk.Jute.Parser.parse_type("long")
        {:ok, [type: :long], "", %{}, {1, 0}, 4}

        iex> ExZk.Jute.Parser.parse_type("float")
        {:ok, [type: :float], "", %{}, {1, 0}, 5}

        iex> ExZk.Jute.Parser.parse_type("double")
        {:ok, [type: :double], "", %{}, {1, 0}, 6}

        iex> ExZk.Jute.Parser.parse_type("ustring")
        {:ok, [type: :ustring], "", %{}, {1, 0}, 7}

        iex> ExZk.Jute.Parser.parse_type("buffer")
        {:ok, [type: :buffer], "", %{}, {1, 0}, 6}

        iex> ExZk.Jute.Parser.parse_type("Id")
        {:ok, [type: ~c"Id"], "", %{}, {1, 0}, 2}

        iex> ExZk.Jute.Parser.parse_type("org.apache.zookeeper.data.Stat")
        {:ok, [type: ~c"org.apache.zookeeper.data.Stat"], "", %{}, {1, 0}, 30}

        iex> ExZk.Jute.Parser.parse_type("vector<int>")
        {:ok, [type: {:vector, :int}], "", %{}, {1, 0}, 11}

        iex> ExZk.Jute.Parser.parse_type("vector<org.apache.zookeeper.data.ACL>")
        {:ok, [type: {:vector, ~c"org.apache.zookeeper.data.ACL"}], "", %{}, {1, 0}, 37}

        iex> ExZk.Jute.Parser.parse_type("map<int, ustring>")
        {:ok, [type: {:map, :int, :ustring}], "", %{}, {1, 0}, 17}

    """
    defparsec(
      :parse_type,
      choice([
        string("byte") |> replace(:byte),
        string("boolean") |> replace(:boolean),
        string("int") |> replace(:int),
        string("long") |> replace(:long),
        string("float") |> replace(:float),
        string("double") |> replace(:double),
        string("ustring") |> replace(:ustring),
        string("buffer") |> replace(:buffer),
        parsec(:map),
        parsec(:vector),
        parsec(:module_name)
      ])
      |> unwrap_and_tag(:type)
    )

    defcombinator(
      :map,
      string("map")
      |> ignore(lt)
      |> parsec(:skip)
      |> parsec(:parse_type)
      |> parsec(:skip)
      |> ignore(comma)
      |> parsec(:skip)
      |> parsec(:parse_type)
      |> parsec(:skip)
      |> ignore(rt)
      |> reduce({:to_map, []})
    )

    def to_map(["map", {:type, key}, {:type, value}]), do: {:map, key, value}

    defcombinatorp(
      :vector,
      string("vector")
      |> ignore(lt)
      |> parsec(:skip)
      |> parsec(:parse_type)
      |> parsec(:skip)
      |> ignore(rt)
      |> reduce({:to_vector, []})
    )

    def to_vector(["vector", {:type, type}]), do: {:vector, type}
  end

  @spec parse_file(Path.t()) :: {:ok, list(Module.t()), String.t()} | {:error, reason :: term()}
  def parse_file(path) do
    with {:ok, f} <- File.open(path, [:read, :utf8]),
         data <- IO.read(f, :eof),
         {:ok, modules, rest, _, _, _} <- ExZk.Jute.Parser.parse_file(data) do
      {:ok, modules, rest}
    end
  end
end
