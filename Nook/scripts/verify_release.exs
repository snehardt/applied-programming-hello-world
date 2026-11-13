{:ok, _} = Application.ensure_all_started(:nook)
false = NookWeb.Endpoint.config(:server)
true = Application.fetch_env!(:nook, :secure_cookies)
false = Application.fetch_env!(:nook, :dev_routes)
"https" = NookWeb.Endpoint.config(:url)[:scheme]
{:ok, _} = Ecto.Adapters.SQL.query(Nook.Repo, "SELECT 1")
false = Enum.any?(NookWeb.Router.__routes__(), &(&1.path == "/dev/mailbox"))
IO.puts("PASS: production release boots with secure cookies, explicit HTTPS origin, no development inbox, database connectivity, and HTTP serving disabled")
