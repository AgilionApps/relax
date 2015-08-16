defmodule Relax.Responders do
  use Behaviour

  @moduledoc """
  Convienience methods for generating JSONAPI.org spec Plug.Conn responses.
  """

  @doc """
  Defines the module using JaSerializer that will be used to format successfull
  responses.
  """
  defcallback serializer() :: module

  defmacro __using__(_) do
    quote do
      @behaviour Relax.Responders
      import Relax.Responders
    end
  end

  defmacro okay(conn, model, meta) do
    quote bind_quoted: [conn: conn, model: model, meta: meta] do
      Relax.Responders.send_json(conn, 200, model, __MODULE__, meta)
    end
  end

  defmacro okay(conn, model) do
    quote bind_quoted: [conn: conn, model: model] do
      Relax.Responders.send_json(conn, 200, model, __MODULE__,  %{})
    end
  end

  def not_found(conn) do
    send_error(conn, 404, "Not found")
  end

  defmacro created(conn, model) do
    quote bind_quoted: [conn: conn, model: model] do
      Relax.Responders.send_json(conn, 201, model, __MODULE__)
    end
  end

  defmacro invalid(conn, errors) do
    quote bind_quoted: [conn: conn, errors: errors] do
      Relax.Responders.send_json(conn, 422, errors, __MODULE__)
    end
  end

  def send_json(conn, status, model, module) do
    send_json(conn, status, model, module, nil)
  end

  def send_json(conn, 422, model, module, meta) do
    resp = module.error_serializer.format(model, conn, meta)
    send_formatted(conn, 422, resp)
  end

  def send_json(conn, status, model, module, meta) do
    body = module.serializer.format(model, conn, meta)
    send_formatted(conn, status, body)
  end

  def send_error(conn, status, title) do
    body = %{errors: [%{title: title, code: status}]}
    send_formatted(conn, status, body)
  end

  defp send_formatted(conn, status, body) do
    conn
      |> add_location(body)
      |> Plug.Conn.send_resp(status, Poison.Encoder.encode(body, []))
      |> Plug.Conn.halt
  end

  defp add_location(conn, body) do
    case body[:data][:links]["self"] do
      nil -> conn
      uri -> Plug.Conn.put_resp_header(conn, "location", uri)
    end
  end
end
