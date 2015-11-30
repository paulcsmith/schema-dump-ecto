defmodule Mix.Ecto do
  # Conveniences for writing Mix.Tasks in Ecto.
  @moduledoc false

  @doc """
  Parses the repository option from the given list.

  If no repo option is given, we get one from the environment.
  """
  @spec parse_repo([term]) :: [Ecto.Repo.t]
  def parse_repo(args) do
    parse_repo(args, [])
  end

  defp parse_repo([key, value|t], acc) when key in ~w(--repo -r) do
    parse_repo t, [Module.concat([value])|acc]
  end

  defp parse_repo([_|t], acc) do
    parse_repo t, acc
  end

  defp parse_repo([], []) do
    if app = Keyword.get(Mix.Project.config, :app) do
      case Application.get_env(app, :app_repo) do
        nil -> 
          case Application.get_env(app, :app_namespace, app) do
            ^app -> app |> to_string |> Mix.Utils.camelize
            mod  -> mod |> inspect
          end |> Module.concat(Repo)
        repo ->
          repo
      end |> List.wrap
    else
      Mix.raise "No repository available. Please pass a repo with the -r option."
    end
  end

  defp parse_repo([], acc) do
    Enum.reverse(acc)
  end

  @doc """
  Ensures the given module is a repository.
  """
  def ensure_repo(repos, args) when is_list(repos) do
    Enum.map repos, &ensure_repo(&1, args)
  end

  @spec ensure_repo(module, list) :: Ecto.Repo.t | no_return
  def ensure_repo(repo, args) do
    Mix.Task.run "loadpaths", args

    unless "--no-compile" in args do
      # TODO: Use Mix.Project.compile(args) with v1.1
      Mix.Task.run "compile", args
    end

    case Code.ensure_compiled(repo) do
      {:module, _} ->
        if function_exported?(repo, :__repo__, 0) do
          repo
        else
          Mix.raise "module #{inspect repo} is not a Ecto.Repo. " <>
                    "Please pass a repo with the -r option."
        end
      {:error, error} ->
        Mix.raise "could not load #{inspect repo}, error: #{inspect error}. " <>
                  "Please pass a repo with the -r option."
    end
  end

  @doc """
  Ensures the given repository is started and running.
  """
  @spec ensure_started(Ecto.Repo.t) :: Ecto.Repo.t | no_return
  def ensure_started(repo) do
    {:ok, _} = Application.ensure_all_started(:ecto)

    case repo.start_link do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _}} -> {:ok, nil}
      {:error, error} ->
        Mix.raise "could not start repo #{inspect repo}, error: #{inspect error}"
    end
  end

  @doc """
  Ensures the given pid for repo is stopped.
  """
  def ensure_stopped(repo, pid) do
    # Silence the logger to avoid application down messages.
    Logger.remove_backend(:console)
    repo.stop(pid)
  after
    Logger.add_backend(:console, flush: true)
  end

  @doc """
  Gets the migrations path from a repository.
  """
  @spec migrations_path(Ecto.Repo.t) :: String.t
  def migrations_path(repo) do
    Path.join(repo_priv(repo), "migrations")
  end

  @doc """
  Gets the schema path from the repository.
  """
  @spec schema_path(Ecto.Repo.t) :: String.t
  def schema_path(repo) do
    repo_priv(repo)
  end

  @doc """
  Add me
  """
  @spec schema_filename(Ecto.Repo.t) :: String.t
  def schema_filename(repo) do
    database_info = repo.__adapter__.database_info
    "#{inspect(repo)}-#{database_info.type}-#{database_info.version}.schema"
  end

  @doc """
  Dumps the schema.
  """
  @spec schema_dump(Ecto.Repo.t) :: no_return
  def schema_dump(repo) do
    adapter = repo.__adapter__
    dump = adapter.schema_dump(repo.config)
  end

  @doc """
  Loads the schema. Will raise an exception if there is a database
  type/version mismatch.
  """
  @spec schema_load(Ecto.Repo.t, String) :: no_return
  def schema_load(repo, filename) do
    adapter = repo.__adapter__

    if database_matches?(repo, filename) do
      adapter.schema_load(repo.config, filename)
    else
      raise "Schema Info Mismatch"
    end
  end

  @doc """
  Determines if the database defined in the Repo matches the
  meta data defined in the schema
  """
  @spec database_matches?(Ecto.Repo.t, String) :: boolean
  def database_matches?(repo, filename) do
    adapter = repo.__adapter__
    schema_info = extract_schema_info(adapter, filename)
    database_info = adapter.database_info

    database_match?(schema_info, database_info) && version_match?(repo, schema_info, database_info)
  end
  defp database_match?(schema_info, database_info) do
    schema_info[:type] == database_info[:type]
  end
  defp version_match?(repo, schema_info, database_info) do
    if constraint = repo.config[:schema_version_constraint] do
      Version.match?(schema_info[:version], constraint) &&
      Version.match?(database_info[:version], constraint)
    else
      true
    end
  end

  @doc false
  defp extract_schema_info(adapter, filename) do
    filename
    |> Path.basename()
    |> Path.rootname()
    |> String.split("-")
    |> build_schema_info()
  end
  defp build_schema_info([repo, type, version]) do
    %{repo: repo, type: type, version: version}
  end
  defp build_schema_info(_invalid) do
    raise ArgumentError, "invalid schema file name..."
  end

  @doc """
  Returns the private repository path.
  """
  def repo_priv(repo) do
    config = repo.config()

    Application.app_dir(Keyword.fetch!(config, :otp_app),
      config[:priv] || "priv/#{repo |> Module.split |> List.last |> Mix.Utils.underscore}")
  end

  @doc """
  Asks if the user wants to open a file based on ECTO_EDITOR.
  """
  @spec open?(binary) :: boolean
  def open?(file) do
    editor = System.get_env("ECTO_EDITOR") || ""
    if editor != "" do
      :os.cmd(to_char_list(editor <> " " <> inspect(file)))
      true
    else
      false
    end
  end

  @doc """
  Gets a path relative to the application path.
  Raises on umbrella application.
  """
  def no_umbrella!(task) do
    if Mix.Project.umbrella? do
      Mix.raise "cannot run task #{inspect task} from umbrella application"
    end
  end

  @doc """
  Returns `true` if module implements behaviour.
  """
  def ensure_implements(module, behaviour, message) do
    all = Keyword.take(module.__info__(:attributes), [:behaviour])
    unless [behaviour] in Keyword.values(all) do
      Mix.raise "Expected #{inspect module} to implement #{inspect behaviour} " <>
                "in order to #{message}"
    end
  end
end
