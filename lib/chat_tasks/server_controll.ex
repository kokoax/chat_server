defmodule Tasks.ServerControll do
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
  ChatServer.Supervisorが管理する最上位のプロセス
  """
  def start_link() do
    # GenServer.start_link(__MODULE__, :ok, [name: name])
    # spawn_link(fn -> init_server_loop() end)
    state = Map.put(Map.new, :channel_list, @def_channel_list)
    GenServer.start_link(__MODULE__, state, name: :chat_server)
    # pid = spawn_link(fn -> init_server_loop() end)
    # Process.register pid, :chat_server # サーバプロセスのpidを:chat_serverというアトムに割り当てている
  end

  @doc """
  サーバサイドの処理を開始する前に初期化しておきたい情報を登録
  """
  def init(state) do
    IO.inspect :ok
    Logger.info "Server Initialize"
    # チャンネルの初期リストを作成
    new_state = Map.put(state, :channel_list, @def_channel_list)
    # server_loop()
    {:ok, new_state}
  end

  @doc """
  サーバに接続されたクライアントの情報を登録する
  - 登録する情報 :user
    - pid
    - username
    - channel: 初期は@def_channelで固定
  """
  def add_userdata(state, %{pid: pid, username: username, channel: channel}) do
    Logger.info "User add on Server"
    new_user = %{pid: pid, username: username, channel: channel}

    have_user = state[:user]
    # nilなら登録されているユーザがいないので、リスト連結ができないため
    # 処理を分けている
    new_userlist = if have_user == nil do
      Logger.info "put head pid"
      [new_user]
    else
      Logger.info "add pid"
      have_user ++ [new_user]
    end
    Map.put(
      state,
      :user,
      new_userlist
    )
  end

  @doc """
  channelをちゃんとした状態に変換
  妥当でないなら、デフォルトチャンネルを
  妥当なら、そのまま返す。
  """
  def channel_check(state, channel) do
    cond do
      channel == nil ->
        @def_channel
      state[:channel_list] |> Enum.any?(&(&1 != channel)) ->
        Map.put(
          state,
          :channel_list,
          state[:channel_list] ++ [channel]
        )
        channel
      true ->
        channel
    end
  end

  @doc """
  ユーザの情報がサーバが保持するに当たって
  妥当であるか判定して、ユーザデータを返す。
  そうでないなら理由をstringで返す。
  """
  def user_check(state, pid, username, channel) do
    all_user = state[:user]
    channel = channel_check(state, channel)

    cond do
      # ユーザ名に空白が含まれている
      username =~ ~r/.*\s.*/ ->
        {:err, "This username is contain whitespace.\n"}
      # ユーザがいないなら被りようがない
      all_user == nil ->
        {:ok, %{pid: pid, username: username, channel: channel}}
      # 既に存在するユーザ名
      all_user |> Enum.any?(&(&1.username == username)) ->
        {:err, "This username is already exist.\n"}
      # 大丈夫なデータ
      true ->
        {:ok, %{pid: pid, username: username, channel: channel}}
    end
  end

  @doc """
  指定したpidのユーザの所属チャンネルをchannelに変更した:userリストを返す
  """
  def mod_channel(state, pid, channel) do
    state[:user]
    |> Enum.map(fn(data) ->
      if data.pid == pid do
        %{
          pid: data.pid,
          username: data.username,
          channel: channel
        }
      else
        data
      end
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
  def get_user_list(state, %{channel: channel}) do
    case get_user_data(state, %{channel: channel}) do
      nil ->
        nil
      user_data ->
        case state[:user] do
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
  def get_user_list(state, %{pid: pid}) do
    case get_user_data(state, %{pid: pid}) do
      nil ->
        nil
      user_data ->
        case state[:user] do
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
  def same_channel_user_data(state, channel) do
    case state[:user] do
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
  def get_user_data(state, %{channel: channel}) do
    case state[:user] do
      nil ->
        nil
      user_data ->
        user_data
        |> Enum.filter(&(&1.channel == channel))
        |> Enum.at(0)
    end
  end
  def get_user_data(state, %{username: username}) do
    case state[:user] do
      nil ->
        nil
      user_data ->
        user_data
        |> Enum.filter(&(&1.username == username))
        |> Enum.at(0)
    end
  end
  def get_user_data(state, %{pid: pid}) do
    case state[:user] do
      nil ->
        nil
      user_data ->
        user_data
        |> Enum.filter(&(&1.pid == pid))
        |> Enum.at(0)
    end
  end

  @doc """
  pidと同じチャンネルに所属している全てのユーザに対しsay_argのイベントを実行
  テキストをクライアントに対して送ることを目的としている。がそれ以外もできる
  myself: 自分自身にも送信するかどうか
  """
  def saying(state, pid, say_arg, myself \\ true)

  def saying(state, pid, say_arg, myself) do
    case get_user_data(state, %{pid: pid}) do
      nil ->
        nil
      user_data ->
        # 同じチャンネルの人にのみ発言
        same_channeler = same_channel_user_data(state, user_data.channel)
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
  def handle_cast({:new, pid, %{username: username, channel: channel}}, state) do
    # 新しく参加したクライアントの情報を登録
    Logger.info "New connection create command on server"
    new_state =
      case user_check(state, pid, username, channel) do
        {:err, err_text} ->
          # 新しくユーザをサーバに登録できなかったら
          send(pid, {:error, err_text})
          state
        {:ok, new_user} ->
          new_state = add_userdata(state, new_user)
          saying(new_state, pid, {:join, new_user.username, new_user.channel}, true)
          new_state
    end
    new_state |> IO.inspect
    {:noreply, new_state}
  end

  def handle_cast({:now_channel, pid}, state) do
    # リクエストしてきたクライアントが現在所属しているチャンネルをsend
    Logger.info "Now channel command on server"
    user_data = get_user_data(state, %{pid: pid})
    send(pid, {:announce, "#{user_data.channel}\n"})
    {:noreply, state}
  end

  def handle_cast({:channel_list, pid}, state) do
      # サーバが保持しているチャンネルのリストをsend
    Logger.info "Channel list command on server"
    send(pid, {:channel_list, "#{state[:channel_list] |> Enum.join("\n")}\n"})
    {:noreply, state}
  end

  def handle_cast({:user_list_pid, pid}, state) do
      # サーバに接続しているクライアントのユーザ名のリストをsend
    Logger.info "user list pid command on server"
    user_list = get_user_list(state, %{pid: pid})
    send(pid, {:user_list, "#{user_list |> Enum.join("\n")}\n"})
    {:noreply, state}
  end

  def handle_cast({:user_list_channel, pid, channel}, state) do
    # サーバに接続しているクライアントのユーザ名のリストをsend
    Logger.info "user list channel command on server"
    user_list = get_user_list(state, %{channel: channel})
    if user_list == nil do
      Logger.info "#{channel} channel don't have user."
      send(pid, {:announce, "#{channel} channel don't have user.\n"})
    else
      Logger.info "Success user list channel"
      send(pid, {:user_list, "#{user_list |> Enum.join("\n")}\n"})
    end
    {:noreply, state}
  end

  def handle_cast({:create, pid, channel}, state) do
    # 指定したchannelを新しく作成し、作成したユーザを
    # 新しく作成したチャンネルへ移動
    Logger.info "Create command on server"
    new_state = if not (state[:channel_list] |> Enum.any?(&(&1 == channel))) do
      new_state = Map.put(state, :channel_list, state[:channel_list]++[channel])
      send(pid, {:announce, "Create #{channel} channel successful\n"})
      new_state
    else
      send(pid, {:announce, "#{channel} channel is already exist.\n"})
      state
    end
    {:noreply, new_state}
  end

  def handle_cast({:delete, pid, channel}, state) do
    # 指定したchannelを削除する
    Logger.info "Delete command on server"
    new_state = cond do
      state[:channel_list]
      |> Enum.filter(&(&1 == channel))
      |> Enum.count == 0 ->
        Logger.info "Missing. Don't exist #{channel} channel\n"
        send(pid, {:announce, "Don't exist #{channel} channel\n"})
        state
      state[:user]
      |> Enum.filter(&(&1.channel == channel))
      |> Enum.count == 0 ->
        Logger.info "Delete #{channel} channel successful\n"
        Map.put(
          state,
          :channel_list,
          state[:channel_list] |> Enum.filter(&(&1 != channel)))
          send(pid,{:announce, "Delete #{channel} channel successful\n"})
      true ->
        Logger.info "Missing. #{channel} channel has user\n"
        send(pid,
             {:announce,
               "Delete missing.\n#{channel} channel has user\n"})
        state
    end
    {:noreply, new_state}
  end

  def handle_cast({:move, pid, channel}, state) do
      # リクエストしてきたクライアントのチャンネルを指定されたチャンネルへmove
    Logger.info "Move command on server"
    new_state = cond do
      (get_user_data(state, %{pid: pid})).channel == channel ->
        Logger.info "Already join to #{channel} channel"
        send(pid, {:announce, "Already join to #{channel} channel\n"})
        state
      state[:channel_list] |> Enum.any?(&(&1 == channel)) ->
        Logger.info "Success Move command"
        Logger.info "Move command on server"
        user_data = get_user_data(state, %{pid: pid})
        saying(state, pid, {:leave, user_data.username, user_data.channel}, false)
        new_state = Map.put(state, :user, mod_channel(state, pid, channel))
        saying(new_state, pid, {:join,  user_data.username, channel}, true)
        new_state
      true ->
        Logger.info "Not found channel"
        send(pid, {:announce, "Not found channel\n"})
        state
    end
    {:noreply, new_state}
  end

  def handle_cast({:whisper, pid, send_user, opponent, body}, state) do
    # 指定されたユーザ名(opponent)のユーザに対してメッセージ(body)を送信
    Logger.info "Wihsper command on server"
    opp_data = get_user_data(state, %{username: opponent})
    cond do
      opp_data == nil ->
        Logger.info "Not found user"
        send(pid, {:announce, "Not found user\n"})
      opp_data.username == send_user ->
        Logger.info "Whisping to myself"
        send(pid, {:announce, "It's you!\n"})
      true ->
        Logger.info "Whisping to #{opp_data.username}"
        send(pid, {:say, send_user <> " to " <> opp_data.username, body})
        send(opp_data.pid, {:say, send_user, body})
    end
    {:noreply, state}
  end

  def handle_cast({:help, pid}, state) do
    # pidのユーザにヘルプを表示
    Logger.info "Help command on server"
    send(pid, {:announce, @help})
    {:noreply, state}
  end

  def handle_cast({:exit, pid}, state) do
    # pidのユーザをサーバから削除
    Logger.info "Exit command on server"
    user_data = get_user_data(state, %{pid: pid})

    # clientにexitを投げる
    send(pid, {:exit})

    # ログイン時エラーとかだと、ユーザデータを取得できない場合もある
    new_state = if user_data != nil do
      saying(state, pid, {:leave, user_data.username, user_data.channel}, false)
      # exitしたpidのユーザ情報をfilterにかけて削除したものを再登録
      Map.put(
        state,
        :user,
        state[:user]
        |> Enum.filter(fn(user_data) -> user_data.pid != pid end)
      )
    end
    {:noreply, new_state}
  end

  def handle_cast({:say, sender_pid, username, body}, state) do
    # sender_pidと同じチャンネルのユーザに対してsender_pidからのメッセージを送信
    Logger.info "Say command on server"
    saying(state, sender_pid, {:say, username, body})
    {:noreply, state}
  end

  def handle_cast({:announce, sender_pid, body}, state) do
    # sender_pidと同じチャンネルのユーザに対して
    # サーバからのアナウンスメッセージを送信
    Logger.info "Announce command on server"
    saying(state, sender_pid, {:annouce, body})
    {:noreply, state}
  end
  def handle_cast(other) do
    IO.inspect other
  end
end
