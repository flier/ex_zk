defmodule Mix.Tasks.Bindgen do
  use Mix.Task

  @shortdoc "Generates the elixir bindings for the Zookeeper wire protocol"

  def run(_) do
    with {:ok, modules, _} <-
           ExZk.Jute.parse_file(Path.expand("./zookeeper.jute", :code.priv_dir(:ex_zk))),
         generated <-
           ExZk.Jute.Binding.generate(modules,
             namespaces: %{
               "org.apache.zookeeper" => "ExZk"
             },
             skip: [
               "org.apache.zookeeper.server"
             ]
           ),
         :ok <- File.write("./lib/ex_zk/protocol.ex", generated) do
    end
  end
end
