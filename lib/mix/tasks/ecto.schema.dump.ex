defmodule Mix.Tasks.Ecto.Schema.Dump do
  use Mix.Task
  import Mix.Ecto
  import Mix.Generator

  @shortdoc "Dumps the current environment's database schema to disk"

  @moduledoc """
  """

  def run(args) do
    no_umbrella!("ecto.schema.dump")

    [repo] = parse_repo(args)
    ensure_repo(repo, args)

    path = Path.relative_to(schema_path(repo), Mix.Project.app_path)
    file = Path.join(path, schema_filename(repo))
    create_directory path
    create_file file, schema_dump(repo), force: true
  end
end
