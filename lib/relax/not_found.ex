defmodule Relax.NotFound do
  @behaviour Plug

  @moduledoc """
  A plug that halts plug stack processing and returns 404 with reason.
  """

  def init(opts), do: opts

  def call(conn, opts) do
    message = case {opts[:title], opts[:type]} do
      {nil, :resource} -> "No matching action found for this resource."
      {nil, :route}    -> "No resource found at this path."
      {message, _}     -> message
    end

    conn
    |> Relax.Responders.send_error(404, message)
    |> Plug.Conn.halt
  end
end
