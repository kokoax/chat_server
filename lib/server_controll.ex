defmodule ServerControll do
  @moduledoc """
  TODO: 書け
  TODO: create channel
  """
  require Logger

  @doc """
  サーバサイドの処理を開始する前に初期化しておきたい情報を登録
  """
  def init_server_loop do
    # チャンネルの初期リストを作成
    Process.put(:channel_list, ["general", "random"])
    server_loop()
  end

  @doc """
  サーバに接続されたクライアントの情報を登録する
  - 登録する情報 :user
    - pid
    - username
    - channel: 初期は"general"で固定
  """
  def add_userdata(pid, username) do
    have_user = Process.get(:user)
    # nilなら登録されているユーザがいないので、リスト連結ができないため
    # 処理を分けている
    if have_user == nil do
      Logger.info "put head pid"
      [%{pid: pid, username: username, channel: "general"}]
    else
      Logger.info "add pid"
      have_user ++ [%{pid: pid, username: username, channel: "general"}]
    end
  end

  @doc """
  指定したpidのユーザの所属チャンネルをchannelに変更した:userリストを返す
  """
  def mod_channel(pid, channel) do
    Process.get(:user)
    |> Enum.map(fn(data) ->
      if data.pid == pid do %{pid: data.pid, username: data.username, channel: channel}
      else data end
    end)
  end

  @doc """
  指定したpidと同じチャンネルのユーザ名一覧
  """
  def get_user_list(pid) do
    user_data = get_user_data(pid)
    Process.get(:user)
    |> Enum.filter(fn(data) ->
      data.channel == user_data.channel
    end)
    |> Enum.map(&(&1.username))
  end

  @doc """
  指定したチャンネルに所属している:userデータを取得
  """
  def same_channel_user_data(channel) do
    Process.get(:user)
    |> Enum.filter(fn(data) ->
      data.channel == channel
    end)
  end

  @doc """
  指定したpidの:userデータを取得
  """
  def get_user_data(pid) do
    Process.get(:user)
    |> Enum.filter(fn(data) ->
      data.pid == pid
    end)
    |> Enum.at(0)
  end

  @doc """
  Mapから:usernameだけを取り出す
  """
  def get_username(%{username: username}) do
    username
  end

  @doc """
  Mapから:pidだけを取り出す
  """
  def get_pid(%{pid: pid}) do
    pid
  end

  @doc """
  ClientControllモジュールからサーバでの処理を要求されるので
  それに応じた処理を実行
  """
  def server_loop do
    receive do
      {:new, pid, username} ->  # 新しく参加したクライアントの情報を登録
        Process.put(:user, add_userdata(pid, username))
        server_loop()
      {:now_channel, pid} -> # リクエストしてきたクライアントが現在所属しているチャンネルをsend
      [user_data] = Process.get(:user) |> Enum.filter(fn(data) -> data.pid == pid end)
        send(pid, {:announce, "#{user_data.channel}\n"})
        server_loop()
      {:channel_list, pid} -> # サーバが保持しているチャンネルのリストをsend
        send(pid, {:channel_list, "#{Process.get(:channel_list) |> Enum.join("\n")}\n"})
        server_loop()
      {:user_list, pid} -> # サーバに接続しているクライアントのユーザ名のリストをsend
        user_list = get_user_list(pid)
        send(pid, {:user_list, "#{user_list |> Enum.join("\n")}\n"})
        server_loop()
      {:move, pid, channel} -> # リクエストしてきたクライアントのチャンネルを指定されたチャンネルへmove
        if Process.get(:channel_list) |> Enum.any?(&(&1 == channel)) do
          Process.put(:user, mod_channel(pid, channel))
          send(pid, {:move, channel})
        else
          send(pid, {:announce, "Not found channel\n"})
        end
        server_loop()
      {:whisper, pid, send_user, opponent, body} -> # 指定されたユーザ名(opponent)のユーザに対してメッセージ(body)を送信
        Logger.info "Wihsper command on server_loop"
        # 相手の:userデータを取得 TODO: 関数化
        opp_data = Process.get(:user) |> Enum.filter(&(&1.username == opponent))
        cond do
          opp_data == [] ->
            Logger.info "Not found user"
            send(pid, {:announce, "Not found user\n"})
          opp_data |> Enum.at(0) |> get_username == send_user -> # TODO: ユーザ名がかぶってると想定外の動作になる
            Logger.info "Whisping to myself"
            send(pid, {:announce, "It's you!\n"})
          true ->
            Logger.info "Whisping to #{opp_data |> Enum.at(0) |> get_username}"
            send(opp_data |> Enum.at(0) |> get_pid, {:say, send_user, body})
        end
        server_loop()
      {:exit, pid} ->
        # exitしたpidのユーザ情報をfilterにかけて削除したものを再登録
        Process.put(
          :user,
          Process.get(:user) |> Enum.filter(fn(data) -> data.pid != pid end)
        )
        server_loop() # TODO: 記憶にないなぜ？
      # TODO: sayとannounceをもうちょいスマートに
      {:say, sender_pid, username, body} ->
        Logger.info "Say to same channel from server"
        sender_data  = get_user_data(sender_pid)
        # 同じチャンネルの人にのみ発言
        same_channeler = same_channel_user_data(sender_data.channel)
        if same_channeler != [] do
          same_channeler
          |> Enum.map(fn(data) ->
            send(data.pid, {:say, username, body})
          end)
        end
        server_loop()
      {:announce, sender_pid, body} ->
        Logger.info "Server announce to specific channel from username"
        sender_data  = get_user_data(sender_pid)
        # 同じチャンネルの人にのみ発言
        same_channeler = same_channel_user_data(sender_data.channel)
        if same_channeler != [] do
          same_channeler
          |> Enum.map(fn(data) ->
            send(data.pid, {:announce, body})
          end)
        end
        server_loop()
    end
  end
end
