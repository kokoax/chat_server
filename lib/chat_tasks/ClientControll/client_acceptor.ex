defmodule ChatTasks.ClientControll.ClientAcceptor do

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

  def add_client(client) do
    import Supervisor.Spec

    {:ok, user_data} = :gen_tcp.recv(client,0)
    children = [
      worker(ServerSender, [client],     [name: ChatTasks.ClientControll.Supervisor]),
    ]
    # announce = Task.async(fn -> client |> ServerSender.announce_wait end)
    {:ok, announce_pid} = Supervisor.start_link(children, [strategy: :one_for_one])
    # 実際にclientをcloseするのがannounce_waitプロセスのため、controlling_processに割り当てている
    :ok = :gen_tcp.controlling_process(client, announce_pid)

    # Clientからの切断要請を受け、writing.pidを接続されているクライアント一覧から削除するため
    GenServer.cast(:chat_server, {:new, announce_pid, user_data |> eval})

    Task.async(fn ->
      client
      |> ServerReveiver.writing_wait(announce_pid)
    end)
  end


  @doc """
  クライアントからの接続を受けたら、クライアントに対する処理を並列化して実行し、
  次のクライアントからの接続を待つ処理を繰り返す
  """
  def client_loop(sock) do
    client = accept(sock)
    Logger.info "Client Accept !"

    add_client(client)

    client_loop(sock)
  end

end

