defmodule Mix.Tasks.Deps.Licenses do
  use Mix.Task
  alias Hex.Registry.Server, as: Registry

  @shortdoc "Lists license information for your dependencies"

  @moduledoc """
  Checks all your dependencies from your mix.lock file and reads the license information from
  their `hex_metadata.config` and prints it CSV format.
  If a dependency does not have a `hex_metadata.config` it prints "Could not find license information".

  """

  @doc false
  def run(_) do
    Hex.check_deps()
    Hex.start()
    Registry.open()

    lock = Mix.Dep.Lock.read()

    lock
    |> Hex.Mix.packages_from_lock()
    |> Hex.Registry.Server.prefetch()

    packages_info =
      lock
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map(fn name ->
        case :file.consult('./deps/' ++ Atom.to_charlist(name) ++ '/hex_metadata.config') do
          {:ok, config} ->
            config_to_license_info(config, name)

          {:error, _} ->
            [Atom.to_string(name), "Could not find license information"]
        end
      end)

    print_licenses(packages_info)
  end

  @spec config_to_license_info([tuple], String.t()) :: [String.t()]
  defp config_to_license_info(config, name) do
    version = Enum.find_value(config, fn {k, v} -> if k == "version", do: v end)

    license =
      case Enum.find(config, fn {k, _v} -> k == "licenses" end) do
        {_, licenses} -> Enum.join(licenses, " / ")
        _other -> "Could not find license information"
      end

    repo =
      config
      |> Enum.find_value(fn {k, v} -> if k == "links", do: v end)
      |> Enum.find_value(fn {k, v} -> if String.downcase(k) == "github", do: v end)

    {Atom.to_string(name), version, license, repo}
  end

  defp print_licenses(packages_info) do
    IO.puts("name,version,license,repo")
    for {name, version, license, repo} <- packages_info, do: IO.puts("#{name},#{version},#{license},#{repo}")
  end
end
