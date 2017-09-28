defmodule ChatTasks.ClientControll.ServerReveiver do
  use GenServer
  require Logger

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
end
