defmodule Mix.Tasks.Ecto.Schema.LoadTest do
  use ExUnit.Case, async: true

  import Mix.Generator
  import Support.FileHelpers
  import Mix.Tasks.Ecto.Schema.Load, only: [run: 1]

  defmodule Adapter do
    def schema_load(_config, _schema), do: :ok
    def database_info, do: %{type: "foo", version: "1.0.0"}
    defmacro __before_compile__(_), do: :ok
  end

  defmodule Repo do
    def __repo__, do: true
    def __adapter__, do: Adapter

    def config do
      [priv: "tmp/#{inspect(Ecto.Schema.Load)}", otp_app: :ecto]
    end
  end

  defmodule RepoConstraint do
    def __repo__, do: true
    def __adapter__, do: Adapter

    def config do
      [ priv: "tmp/#{inspect(Ecto.Schema.Load)}",
        otp_app: :ecto,
        schema_version_constraint: "= 1.0.0"]
    end
  end

  defmodule AdapterConstraint do
    def schema_load(_config, _schema), do: :ok
    def database_info, do: %{type: "foo", version: "3.0.0"}
    defmacro __before_compile__(_), do: :ok
  end

  defmodule RepoAdapterConstraint do
    def __repo__, do: true
    def __adapter__, do: AdapterConstraint

    def config do
      [ priv: "tmp/#{inspect(Ecto.Schema.Load)}",
        otp_app: :ecto,
        schema_version_constraint: "= 1.0.0"]
    end
  end

  test "raises no exception when there is no version constraint defined" do
    assert run ["Mix.Tasks.Ecto.Schema.LoadTest.Repo-foo-1.0.0.schema", "-r", to_string(Repo)]
  end

  test "raises an exception when database type mismatch" do
    assert_raise RuntimeError, fn ->
      assert run ["Mix.Tasks.Ecto.Schema.LoadTest.Repo-bar-1.0.0.schema", "-r", to_string(Repo)]
    end
  end

  test "raises no exception when there is a version constraint defined that does match" do
    assert run ["Mix.Tasks.Ecto.Schema.LoadTest.RepoConstraint-foo-1.0.0.schema", "-r", to_string(Repo)]
  end

  test "raises Version.InvalidRequirementError exception when there is a version constraint defined that does not match the schema version" do
    assert_raise Version.InvalidRequirementError, fn ->
      assert run ["Mix.Tasks.Ecto.Schema.LoadTest.RepoConstraint-foo-2.0.0.schema", "-r", to_string(RepoConstraint)]
    end
  end

  test "raises Version.InvalidRequirementError exception when there is a version constraint defined that does not match the adapter's version" do
    assert_raise Version.InvalidRequirementError, fn ->
      assert run ["Mix.Tasks.Ecto.Schema.LoadTest.RepoConstraint-foo-2.0.0.schema", "-r", to_string(RepoAdapterConstraint)]
    end
  end
end
