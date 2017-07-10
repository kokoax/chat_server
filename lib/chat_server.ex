defmodule ChatServer.Supervisor do
  @moduledoc """
  - CUIチャットシステムのサーバサイドの実装
  ## Arguments
  - ``--port,-p``
    - サーバの利用するポート番号を指定
  ## Usage
  - ``$ ./chat_server --port 1600``
  - ``$ ./chat_server -p 65535``
  ## Process.getで取得できるデータ
  - Process.get(:user)
    - チャットに参加しているユーザのデータ一覧
    - ``[{pid, username, channel}, {pid, username, ...}, {...}, ...]``
  - Process.get(:channel_list)
    - 現在存在するチャンネルのリスト
    - ``["general", "random", ...]``
  """
  require Logger

  @doc """
  サーバ実行のための引数の条件を満たしていない場合
  """
  def do_process(nil) do
    IO.warn "Don't enough options"
  end

  @doc """
  portでサーバを起動して、クライアントからの接続受付を開始する
  """
  def do_process([port]) do
    import Supervisor.Spec

    {:ok, sock} = :gen_tcp.listen(port, [:binary, packet: 0, active: false])
    children = [
      worker(Tasks.ServerControll, [],     [name: :chat_server]),
      # worker(Tasks.ClientControll, [sock], [name: :chat_client]),
    ]
    {:ok, pid} = Supervisor.start_link(children, strategy: :one_for_one)

    Logger.info "To Start Server Controll Loop"
    # pid = spawn_link(fn -> ServerControll.init_server_loop() end)
    # Process.register pid, :chat_server  # サーバプロセスのpidを:chat_serverというアトムに割り当てている

    Logger.info "To Start Client Controll Loop"
    Tasks.ClientControll.client_loop(sock)
  end

  @doc """
  プログラムの引数をパースしてそれに応じて処理を振り分ける
  """
  def parse_argv(argv) do
    {options, _, _} = argv |> OptionParser.parse(
      switches: [port: :integer],
      aliases:  [p: :port],
    )
    # keyword listだと順番が保持され、面倒なのでMapでpattern match
    case options |> Enum.into(%{}) do
      %{port: port} ->
        [port]
      _ ->
        nil
    end
  end

  @doc """
  メインプログラム
  """
  def main(opts) do
    Logger.info "Chat Server is Running !"
    opts |> parse_argv |> do_process
  end
end

