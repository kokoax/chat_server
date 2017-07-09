defmodule ServerControll do
  @moduledoc """
  サーバ側が実際にクライアントから指定された処理を行うモジュール
  また、クライアントの情報や、チャンネル情報などのデータを保持しているのもこのモジュール
  """
  require Logger
  @def_channel "general"
  @def_channel_list ["general", "random"]
  @help """
  :exit -> クライアントを終了する。
  :help -> ヘルプを表示する。
  :channel_list -> チャンネルの一覧を表示する。
  :now_channel -> クライアントが現在所属しているチャンネルを表示する。
  :user_list -> クライアントが現在所属しているチャンネルのユーザ一覧を表示する。
  :user_list $(channel) -> 指定したchannelに所属しているユーザ一覧を表示する。
  :move $(channel) -> クライアントの所属チャンネルを指定したchannelに移動する。
  :create $(channel) -> 新しくchannelを作成し、クライアントの所属チャンネルを新しく作成したchannelへ移動する。
  :delete $(channel) -> 指定したchannelを削除する。
  :whisper $(username) $(message) -> 指定したusernameのユーザに対してmessageを送信する。
  other -> クライアントが現在所属しているチャンネルに対してother(入力されたtext)を送信する。
  """

  @doc """
  サーバサイドの処理を開始する前に初期化しておきたい情報を登録
  """
  def init_server_loop do
    Logger.info "Server Initialize"
    # チャンネルの初期リストを作成
    Process.put(:channel_list, @def_channel_list)
    server_loop()
  end

  @doc """
  サーバに接続されたクライアントの情報を登録する
  - 登録する情報 :user
    - pid
    - username
    - channel: 初期は@def_channelで固定
  """
  def add_userdata(pid, username, channel) do
    Logger.info "User add on Server"
    have_user = Process.get(:user)
    # nilなら登録されているユーザがいないので、リスト連結ができないため
    # 処理を分けている
    if have_user == nil do
      Logger.info "put head pid"
      [%{pid: pid, username: username, channel: channel}]
    else
      Logger.info "add pid"
      have_user ++ [%{pid: pid, username: username, channel: channel}]
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
  指定した引数と同じチャンネルを持つユーザ一覧を取得
  ### argument
  - %{username: "any username"}
    - ユーザ名(ここでは、"any username")から検索
  - %{pid: #PID<x.xx.x>}
    - ユーザ名(ここでは、#PID{x.xx.x})から検索
  """
  def get_user_list(%{channel: channel}) do
    case get_user_data(%{channel: channel}) do
      nil ->
        nil
      user_data ->
        case Process.get(:user) do
          nil ->
            nil
          user ->
            user
            |> Enum.filter(fn(data) ->
              data.channel == user_data.channel
            end)
            |> Enum.map(&(&1.username))
        end
    end
  end

  def get_user_list(%{pid: pid}) do
    case get_user_data(%{pid: pid}) do
      nil ->
        nil
      user_data ->
        case Process.get(:user) do
          nil ->
            nil
          user ->
            user
            |> Enum.filter(fn(data) ->
              data.channel == user_data.channel
            end)
            |> Enum.map(&(&1.username))
        end
    end
  end

  @doc """
  指定したチャンネルに所属している:userデータを取得
  """
  def same_channel_user_data(channel) do
    case Process.get(:user) do
      nil ->
        nil
      data ->
        data
        |> Enum.filter(fn(data) ->
          data.channel == channel
        end)
    end
  end

  @doc """
  指定した引数と同じ情報を持つ:userデータを取得
  ### argument
  - %{pid: #PID<x.xx.x>}
    - ユーザ名(ここでは、#PID{x.xx.x})から検索
  - %{username: "any username"}
    - ユーザ名(ここでは、"any username")から検索
  - %{channe: "any channel"}
    - チャンネル名(ここでは、"any channel")から検索
  """
  def get_user_data(%{channel: channel}) do
    case Process.get(:user) do
      nil ->
        nil
      user_data ->
        user_data
        |> Enum.filter(&(&1.channel == channel))
        |> Enum.at(0)
    end
  end
  def get_user_data(%{username: username}) do
    case Process.get(:user) do
      nil ->
        nil
      user_data ->
        user_data
        |> Enum.filter(&(&1.username == username))
        |> Enum.at(0)
    end
  end
  def get_user_data(%{pid: pid}) do
    case Process.get(:user) do
      nil ->
        nil
      user_data ->
        user_data
        |> Enum.filter(&(&1.pid == pid))
        |> Enum.at(0)
    end
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
  pidと同じチャンネルに所属している全てのユーザに対しsay_argのイベントを実行
  テキストをクライアントに対して送ることを目的としている。がそれ以外もできる
  myself: 自分自身にも送信するかどうか
  """
  def saying(pid, say_arg, myself \\ true)

  def saying(pid, say_arg, myself) do
    case get_user_data(%{pid: pid}) do
      nil ->
        nil
      user_data ->
        # 同じチャンネルの人にのみ発言
        same_channeler = same_channel_user_data(user_data.channel)
        if same_channeler != [] and same_channeler != nil do
          same_channeler
          |> Enum.map(fn(data) ->
            if myself == true or data.pid != pid do
              send(data.pid, say_arg)
            end
          end)
        end
    end
  end

  @doc """
  ClientControllモジュールからサーバでの処理を要求されるので
  それに応じた処理を実行
  """
  def server_loop do
    receive do
      {:new, pid, username} ->  # 新しく参加したクライアントの情報を登録
        Logger.info "New connection create command on server"
        Process.put(:user, add_userdata(pid, username, @def_channel))
        saying(pid, {:join, username, @def_channel}, true)  # TODO: channelを初期設定できるようにする
        server_loop()

      {:now_channel, pid} -> # リクエストしてきたクライアントが現在所属しているチャンネルをsend
        Logger.info "Now channel command on server"
        user_data = get_user_data(%{pid: pid})
        send(pid, {:announce, "#{user_data.channel}\n"})
        server_loop()

      {:channel_list, pid} -> # サーバが保持しているチャンネルのリストをsend
        Logger.info "Channel list command on server"
        send(pid, {:channel_list, "#{Process.get(:channel_list) |> Enum.join("\n")}\n"})
        server_loop()

      {:user_list_pid, pid} -> # サーバに接続しているクライアントのユーザ名のリストをsend
        Logger.info "user list pid command on server"
        user_list = get_user_list(%{pid: pid})
        # TODO: check 自分の所属しているチャンネルのユーザ一覧なので、絶対にユーザを見つけることができるはず
        send(pid, {:user_list, "#{user_list |> Enum.join("\n")}\n"})
        server_loop()

      {:user_list_channel, pid, channel} -> # サーバに接続しているクライアントのユーザ名のリストをsend
        Logger.info "user list channel command on server"
        user_list = get_user_list(%{channel: channel})
        if user_list == nil do
          Logger.info "This #{channel} channel don't have user."
          send(pid, {:announce, "This #{channel} channel don't have user.\n"})
        else
          Logger.info "Success user list channel"
          send(pid, {:user_list, "#{user_list |> Enum.join("\n")}\n"})
        end
        Logger.info "user list channel is over"
        server_loop()

      {:create, pid, channel} ->
        Logger.info "Create command on server"
        if not (Process.get(:channel_list) |> Enum.any?(&(&1 == channel))) do
          Process.put(:channel_list, Process.get(:channel_list)++[channel])
          send(pid, {:announce, "Create #{channel} channel successful\n"})
        else
          send(pid, {:announce, "#{channel} channel is already exist.\n"})
        end
        server_loop()

      {:delete, pid, channel} ->
        Logger.info "Delete command on server"
        cond do
          Process.get(:channel_list) |> Enum.filter(&(&1 == channel)) |> Enum.count == 0 ->
            Logger.info "Missing. Don't exist #{channel} channel\n"
            send(pid, {:announce, "Don't exist #{channel} channel\n"})
          Process.get(:user) |> Enum.filter(&(&1.channel == channel)) |> Enum.count == 0 ->
            Logger.info "Delete #{channel} channel successful\n"
            Process.put(:channel_list, Process.get(:channel_list) |> Enum.filter(&(&1 != channel)))
            send(pid, {:announce, "Delete #{channel} channel successful\n"})
          true ->
            Logger.info "Missing. This #{channel} channel has user\n"
            send(pid, {:announce, "Delete missing.\nThis #{channel} channel has user\n"})
        end
        server_loop()

      {:move, pid, channel} -> # リクエストしてきたクライアントのチャンネルを指定されたチャンネルへmove
        Logger.info "Move command on server"
        cond do
          (get_user_data(%{pid: pid})).channel == channel ->
            Logger.info "Already join to #{channel} channel"
            send(pid, {:announce, "Already join to #{channel} channel\n"})
          Process.get(:channel_list) |> Enum.any?(&(&1 == channel)) ->
            Logger.info "Success Move command"
            Logger.info "Move command on server"
            user_data = get_user_data(%{pid: pid})
            saying(pid, {:leave, user_data.username, user_data.channel}, false)
            Process.put(:user, mod_channel(pid, channel))
            saying(pid, {:join,  user_data.username, channel}, true)
          true ->
            Logger.info "Not found channel"
            send(pid, {:announce, "Not found channel\n"})
        end
        server_loop()

      {:whisper, pid, send_user, opponent, body} -> # 指定されたユーザ名(opponent)のユーザに対してメッセージ(body)を送信
        Logger.info "Wihsper command on server"
        opp_data = get_user_data(%{username: opponent})
        cond do
          opp_data == nil ->
            Logger.info "Not found user"
            send(pid, {:announce, "Not found user\n"})
          opp_data.username == send_user -> # TODO: ユーザ名がかぶってると想定外の動作になる
            Logger.info "Whisping to myself"
            send(pid, {:announce, "It's you!\n"})
          true ->
            Logger.info "Whisping to #{opp_data.username}"
            send(pid, {:say, send_user <> " to " <> opp_data.username, body})
            send(opp_data.pid, {:say, send_user, body})
        end
        server_loop()

      {:help, pid} -> # pidのユーザにヘルプを表示
        Logger.info "Help command on server"
        send(pid, {:announce, @help})
        server_loop()

      {:exit, pid} -> # pidのユーザをサーバから削除
        Logger.info "Exit command on server"
        user_data = get_user_data(%{pid: pid})
        saying(pid, {:leave, user_data.username, user_data.channel}, false)
        # exitしたpidのユーザ情報をfilterにかけて削除したものを再登録
        Process.put(
          :user,
          Process.get(:user) |> Enum.filter(fn(data) -> data.pid != pid end)
        )
        server_loop()

      {:say, sender_pid, username, body} -> # sender_pidと同じチャンネルのユーザに対してsender_pidからのメッセージを送信
        Logger.info "Say command on server"
        saying(sender_pid, {:say, username, body})
        server_loop()

      {:announce, sender_pid, body} -> #  sender_pidと同じチャンネルのユーザに対してサーバからのアナウンスメッセージを送信
        Logger.info "Announce command on server"
        saying(sender_pid, {:annouce, body})
        server_loop()
    end
  end
end
