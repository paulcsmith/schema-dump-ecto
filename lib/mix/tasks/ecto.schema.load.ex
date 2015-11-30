defmodule Mix.Tasks.Ecto.Schema.Load do
  use Mix.Task
  import Mix.Ecto
  import Mix.Generator

  @shortdoc "Loads the current environment's database from schemak"

  @moduledoc """
  """

  def run([file_name|args]) do
    no_umbrella!("ecto.schema.dump")

    [repo] = parse_repo(args)
    ensure_repo(repo, args)

    path = Path.relative_to(schema_path(repo), Mix.Project.app_path)
    schema_load(repo, Path.join(path, file_name))
  end
end
