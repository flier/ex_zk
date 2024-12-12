defmodule Mix.Tasks.Bindgen do
  use Mix.Task

  @shortdoc "Generates the elixir bindings for the Zookeeper wire protocol"

  @jute_file "./zookeeper.jute"
  @binding_file "./lib/ex_zk/protocol.ex"

  @impl true
  def run(_) do
    with {:ok, data} <- File.read(Path.expand(@jute_file, :code.priv_dir(:ex_zk))),
         {:ok, modules, _, _, _, _} <- ExZk.Jute.Parser.parse_file(data),
         generated <-
           ExZk.Jute.Binding.generate(modules,
             namespaces: %{
               "org.apache.zookeeper" => "ExZk",
               "org.apache.zookeeper.data" => "ExZk.Data",
               "org.apache.zookeeper.txn" => "ExZk.Txn"
             },
             skip: [
               "org.apache.zookeeper.server"
             ]
           ),
         :ok <- File.write(@binding_file, generated) do
    end
  end
end
