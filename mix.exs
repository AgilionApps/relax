defmodule Relax.Mixfile do
  use Mix.Project

  def project do
    [app: :relax,
     version: "0.1.0",
     elixir: "~> 1.0.0",
     package: package,
     description: description,
     deps: deps]
  end

  def application do
    [applications: applications(Mix.env)]
  end

  defp applications(:test), do: applications(:all) ++ [:blacksmith]
  defp applications(_all),  do: [:logger]

  defp deps do
    [{:cowboy, "~> 1.0"},
     {:plug,   "~> 0.8"},
     {:inflex, "~> 0.2.5"},
     {:ja_serializer, "~> 0.0.1"},
     {:blacksmith, git: "git://github.com/batate/blacksmith.git", only: :test}]
  end

  defp package do
    [
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/AgilionApps/relax"
      }
    ]
  end

  defp description do
    """
    A jsonapi.org serializer and optional server implementation in Elixir.

    Relax can be used as a standalone API with Relax.Router and Relax.Resources,
    or integrated into Phoenix using Relax.Serializer.
    """
  end
end
