defmodule Nook.MixProject do
  use Mix.Project

  def project do
    [
      app: :nook,
      version: "0.12.2",
      elixirc_paths: if(Mix.env() == :test, do: ["lib", "test/support"], else: ["lib"]),
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: [
        {:assent, "~> 0.3.2"},
        {:ssl_verify_fun, "~> 1.1"},
        {:pbkdf2_elixir, "~> 2.0"},
        {:swoosh, "~> 1.16"},
        {:gen_smtp, "~> 1.3"},
        {:phoenix, "~> 1.8.0"},
        {:phoenix_html, "~> 4.2"},
        {:phoenix_live_view, "~> 1.1.0"},
        {:phoenix_ecto, "~> 4.6"},
        {:ecto_sql, "~> 3.13"},
        {:postgrex, "~> 0.21"},
        {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
        {:lazy_html, ">= 0.1.0", only: :test},
        {:bandit, "~> 1.6"},
        {:jason, "~> 1.4"}
      ]
    ]
  end

  def application do
    [mod: {Nook.Application, []}, extra_applications: [:logger, :crypto, :inets, :ssl]]
  end
end
