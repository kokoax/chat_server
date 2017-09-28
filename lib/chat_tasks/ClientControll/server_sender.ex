defmodule ChatTasks.ClientControll.ServerSender do
  use GenServer
  require Logger

  @announce_user_name "announce-san"

  def start_link(client) do
    GenServer.start_link(__MODULE__, client, name: :chat_server)
  end

  def init(client) do
    {:ok, client}
  end

  @doc """
  リストの一番うしろの要素を削除したリストを返す
  """
  def remove_last([last,_]) do
    [last]
  end
  def remove_last([head|tail]) do
    [head] ++ remove_last(tail)
  end

  @doc """
  特定の形で、クライアントにメッセージを送信する処理を行うプロセス
  """
  def handle_cast({:channel_list, list}, client) do
    Logger.info "show channel list"
    data = ~s(%{event: "message", message: "#{list}"})
    :gen_tcp.send(client, data)
    {:noreply, client}
  end

  def handle_cast({:user_list, list}, client) do
    Logger.info "show user list"
    data = ~s(%{event: "message", message: "#{list}"})
    :gen_tcp.send(client, data)
    {:noreply, client}
  end

  def handle_cast({:join, username, channel}, client) do
    Logger.info "join to any channel\n"
    data = ~s(%{event: "message", message: "#{@announce_user_name}:\n  #{username} Joined to #{channel}\n"})
    :gen_tcp.send(client, data)
    {:noreply, client}
  end

  def handle_cast({:leave, username, channel}, client) do
    Logger.info "leave from any channel\n"
    data = ~s(%{event: "message", message: "#{@announce_user_name}:\n  #{username} Leaved from #{channel}\n"})
    :gen_tcp.send(client, data)
    {:noreply, client}
  end

  def handle_cast({:say, username, body}, client) do
    Logger.info "say recv from other client"
    message = body |> String.split("\n") |> remove_last |> Enum.map(&("  " <> &1)) |> Enum.join("\n")
    data = ~s(%{event: "message", message: "#{username}:\n#{message}\n"})
    :gen_tcp.send(client, data)
    {:noreply, client}
  end

  def handle_cast({:error, body}, client) do
    Logger.info "error happen and close session"
    message =
      body
      |> String.split("\n")
      |> remove_last
      |> Enum.map(&("  " <> &1))
      |> Enum.join("\n")
    data = ~s(%{event: "error", message: "#{@announce_user_name}:\n#{message}\n"})
    :gen_tcp.send(client, data)
    {:noreply, client}
  end

  def handle_cast({:exit}, client) do
    Logger.info "exit of session"
    data = ~s(%{event: "exit", message: "Session is over.\n"})
    :gen_tcp.send(client, data)
    {:noreply, client}
  end

  def handle_cast({:announce, body}, client) do
    Logger.info "say recv from other client"
    message =
      body
      |> String.split("\n")
      |> remove_last
      |> Enum.map(&("  " <> &1))
      |> Enum.join("\n")
    data = ~s(%{event: "message", message: "#{@announce_user_name}:\n#{message}\n"})
    :gen_tcp.send(client, data)
    {:noreply, client}
  end
end
