defmodule Mix.Tasks.Ecto.Schema.DumpTest do
  use ExUnit.Case, async: true

  import Support.FileHelpers
  import Mix.Tasks.Ecto.Schema.Dump, only: [run: 1]

  @tmp_path Path.join(tmp_path, inspect(Ecto.Schema.Dump))

  defmodule Adapter do
    def schema_dump(_config) do
      "--dump--"
    end
    defmacro __before_compile__(_), do: :ok
    def database_info, do: %{type: "foobar", version: "1.0"}
  end

  Application.put_env(:ecto, __MODULE__.Repo, [])

  defmodule Repo do
    def __repo__ do
      true
    end

    def __adapter__ do
      Adapter
    end

    def config do
      [priv: "tmp/#{inspect(Ecto.Schema.Dump)}", otp_app: :ecto]
    end
  end

  test "dumps the schema" do
    run ["-r", to_string(Repo)]

    filename = Path.join(@tmp_path, "Mix.Tasks.Ecto.Schema.DumpTest.Repo-foobar-1.0.schema")

    assert_file filename, fn file ->
      assert file =~ "--dump--"
    end
  end
end
