defmodule Tesla.Middleware.BaseUrl do
  def call(env, run, base) do
    run.(apply_base(env, base))
  end

  def apply_base(env, base) do
    if Regex.match?(~r/^https?:\/\//, env.url) do
      env # skip if url is already with scheme
    else
      %{env | url: join(base, env.url)}
    end
  end

  defp join(base, url) do
    case {String.last(base), url} do
      {"/", "/" <> rest}  -> base <> rest
      {"/", rest}         -> base <> rest
      {_,   "/" <> rest}  -> base <> "/" <> rest
      {_,   rest}         -> base <> "/" <> rest
    end
  end
end

defmodule Tesla.Middleware.Headers do
  def call(env, run, headers) do
    headers = Map.merge(env.headers, headers)
    run.(%{env | headers: headers})
  end
end

defmodule Tesla.Middleware.QueryParams do
  def call(env, run, query) do
    env = %{env | url: merge_url_and_query(env.url, query)}
    run.(env)
  end

  @spec merge_url_and_query(String.t, %{}) :: String.t
  def merge_url_and_query(url, query) do
    query = for {key, val} <- query, into: %{}, do: {to_string(key), val}
    uri = URI.parse(url)
    q = if uri.query do
      env_query = URI.decode_query(uri.query)
      Map.merge(query, env_query)
    else
      query
    end

    uri |> Map.put(:query, URI.encode_query(q)) |> URI.to_string
  end
end

defmodule Tesla.Middleware.DecodeRels do
  def call(env, run, []) do
    env = run.(env)

    if env.headers['Link'] do
      rels = env.headers['Link']
        |> to_string
        |> String.split(",")
        |> Enum.map(&String.strip/1)
        |> Enum.map(fn e -> Regex.run(~r/\A<(.+)>; rel="(.+)"\z/, e, capture: :all_but_first) |> List.to_tuple end)
        |> Enum.reduce(%{}, fn ({url, key}, a) -> Dict.put(a, key, url) end)

      env |> Map.put(:rels, rels)
    else
      env
    end
  end
end

defmodule Tesla.Middleware.AdapterOptions do
  def call(env, run, opts) do
    run.(%{env | opts: env.opts ++ opts})
  end
end

defmodule Tesla.Middleware.BaseUrlFromConfig do
 def call(env, run, opts) do
   run.(%{env | url: config(opts)[:base_url] <> env.url})
 end

 defp config(opts) do
   Application.get_env(Keyword.fetch!(opts, :otp_app), Keyword.fetch!(opts, :module))
 end
end
