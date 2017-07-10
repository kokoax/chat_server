defmodule Tasks.ClientControll do
  @moduledoc """
  サーバに接続してきたクライアントそれぞれに、ソケットを開き、
  クライアントの、データ受信と送信を管理する。
  """
  use GenServer
  require Logger

  @announce_user_name "announce-san"

  @doc """
  クライアントからの接続が来たらacceptしてソケットを戻す
  ここで、sockはサーバのソケットで、clientはクライアントとの接続のためののsocket
  """
  def accept(sock) do
    {:ok, client} = :gen_tcp.accept(sock)
    client
  end

  @doc """
  クライアントからのメッセージは、elixirのMapというデータ構造を文字列にしたもの
  を送信するので、受信したらそのままevalすることで、データを取り出すことができる
  """
  def eval(str) do
    {data, _} = Code.eval_string(str)
    data
  end

  @doc """
  クライアントから送られてきたデータを解析する
  主に、クライアントから指定されたイベントに応じて処理を振り分けるプロセス
  """
  def writing_wait(client, announce_pid) do
    Logger.info "writing wait"
    data = try do
      {:ok, data} = :gen_tcp.recv(client, 0)
      data |> IO.inspect
      data |> eval |> IO.inspect
    rescue
      # 想定外のdataが投げられてくるときがあるので、rescueしてコネクションをclose
      e in MatchError ->
        Logger.warn "MatchError: Maybe unxpected connection break."
        %{event: "error"}
    end

    case data.event do
      "help" ->
        Logger.info "help command"
        GenServer.cast(:chat_server, {:help, announce_pid})
        client |> writing_wait(announce_pid)
      "error" ->
        Logger.info "error happen in login"
        GenServer.cast(:chat_server, {:exit, announce_pid})
      "exit" ->
        Logger.info "exit command"
        GenServer.cast(:chat_server, {:exit, announce_pid})
      "user_list_pid" ->
        Logger.info "user list from pid command"
        GenServer.cast(:chat_server, {:user_list_pid, announce_pid})
        client |> writing_wait(announce_pid)
      "user_list_channel" ->
        Logger.info "user list from channel command"
        GenServer.cast(:chat_server, {:user_list_channel, announce_pid, data.channel})
        client |> writing_wait(announce_pid)
      "channel_list" ->
        Logger.info "channel list command"
        GenServer.cast(:chat_server, {:channel_list, announce_pid})
        client |> writing_wait(announce_pid)
      "now_channel" ->
        Logger.info "now channel command"
        GenServer.cast(:chat_server, {:now_channel, announce_pid})
        client |> writing_wait(announce_pid)
      "move" ->
        Logger.info "move command"
        GenServer.cast(:chat_server, {:move,  announce_pid, data.channel})
        client |> writing_wait(announce_pid)
      "create" ->
        Logger.info "create command"
        GenServer.cast(:chat_server, {:create, announce_pid, data.channel})
        GenServer.cast(:chat_server, {:move,   announce_pid, data.channel})
        client |> writing_wait(announce_pid)
      "delete" ->
        Logger.info "delete command"
        GenServer.cast(:chat_server, {:delete, announce_pid, data.channel})
        client |> writing_wait(announce_pid)
      "whisper" ->
        Logger.info "whisper command"
        GenServer.cast(:chat_server, {:whisper, announce_pid, data.username, data.opponent, data.body})
        client |> writing_wait(announce_pid)
      "say"  ->
        Logger.info "say command"
        GenServer.cast(:chat_server, {:say, announce_pid, data.username, data.body})
        client |> writing_wait(announce_pid)
    end
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
  def announce_wait(client) do
    Logger.info "say wait"
    receive do
      {:channel_list, list} ->
        Logger.info "show channel list"
        data = ~s(%{event: "message", message: "#{list}"})
        :gen_tcp.send(client, data)
        client |> announce_wait

      {:user_list, list} ->
        Logger.info "show user list"
        data = ~s(%{event: "message", message: "#{list}"})
        :gen_tcp.send(client, data)
        client |> announce_wait

      {:join, username, channel} ->
        Logger.info "join to any channel\n"
        data = ~s(%{event: "message", message: "#{@announce_user_name}:\n  #{username} Joined to #{channel}\n"})
        :gen_tcp.send(client, data)
        client |> announce_wait

      {:leave, username, channel} ->
        Logger.info "leave from any channel\n"
        data = ~s(%{event: "message", message: "#{@announce_user_name}:\n  #{username} Leaved from #{channel}\n"})
        :gen_tcp.send(client, data)
        client |> announce_wait

      {:say, username, body} ->
        Logger.info "say recv from other client"
        message = body |> String.split("\n") |> remove_last |> Enum.map(&("  " <> &1)) |> Enum.join("\n")
        data = ~s(%{event: "message", message: "#{username}:\n#{message}\n"})
        :gen_tcp.send(client, data)
        client |> announce_wait

      {:error, body} ->
        Logger.info "error happen and close session"
        message =
          body
          |> String.split("\n")
          |> remove_last
          |> Enum.map(&("  " <> &1))
          |> Enum.join("\n")
        data = ~s(%{event: "error", message: "#{@announce_user_name}:\n#{message}\n"})
        :gen_tcp.send(client, data)

      {:exit} ->
        Logger.info "exit of session"
        data = ~s(%{event: "exit", message: "Session is over.\n"})
        :gen_tcp.send(client, data)

      {:announce, body} ->
        Logger.info "say recv from other client"
        message =
          body
          |> String.split("\n")
          |> remove_last
          |> Enum.map(&("  " <> &1))
          |> Enum.join("\n")
        data = ~s(%{event: "message", message: "#{@announce_user_name}:\n#{message}\n"})
        :gen_tcp.send(client, data)
        client |> announce_wait
    end
  end

  @doc """
  クライアントからの接続を受けたら、クライアントに対する処理を並列化して実行し、
  次のクライアントからの接続を待つ処理を繰り返す
  """
  def client_loop(sock) do
    client = accept(sock)
    Logger.info "Client Accept !"
    {:ok, user_data} = :gen_tcp.recv(client,0)
    announce = Task.async(fn -> client |> announce_wait end)
    # 実際にclientをcloseするのがannounce_waitプロセスのため、controlling_processに割り当てている
    :ok = :gen_tcp.controlling_process(client, announce.pid)
    # Clientからの切断要請を受け、writing.pidを接続されているクライアント一覧から削除するため
    GenServer.cast(:chat_server, {:new, announce.pid, user_data |> eval})

    Task.async(fn -> client |> writing_wait(announce.pid) end)

    client_loop(sock)
  end
end
