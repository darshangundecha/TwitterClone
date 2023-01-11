-module(tweetclient).
-export[beginn/0, test/4].

subList_generate(Counts, Subscribe_Num, List) ->
        if
            (Counts == Subscribe_Num) ->
                [Counts | List];
            true ->
                subList_generate(Counts+1, Subscribe_Num, [Counts | List])
        end.

test_simulator(Sockett, User_Name, _, Subscribe_Num) ->
    if 
        Subscribe_Num > 0 ->
            SubList = subList_generate(1, Subscribe_Num, []),
            handle_subscribe(Sockett, User_Name, SubList)
    end,
    UserToMention = rand:uniform(list_to_integer(User_Name)),
    tweet_sender(Sockett, User_Name, {"~p mentioning @~p in their tweet",[User_Name, UserToMention]}),
    tweet_sender(Sockett, User_Name, {"~p says #HashTag in their tweet",[User_Name]}).


test(User_Name, Tweets_Num, Subscribe_Num, false) ->
    io:fwrite("\nEntry Point for coreengine!\n"),
    PortNumber = 1204,
    IPAddress = "localhost",
    {ok, Sockett} = gen_tcp:connect(IPAddress, PortNumber, [binary, {packet, 0}]),
    register_acCounts(Sockett, User_Name),
    receive
        {tcp, Sockett, Data} ->
            io:format("User ~p registered on server", [Data])
    end,

    test_simulator(Sockett, User_Name, Tweets_Num, Subscribe_Num).

handle_subscribe(Sockett, User_Name, SubList) ->

    [{SubscribeUser_Name}|RemainingList] = SubList,
    subscribe_to_user(Sockett, User_Name, SubscribeUser_Name),
    handle_subscribe(Sockett, User_Name, RemainingList).



recurser(Sockett, User_Name) ->
    receive
        {tcp, Sockett, Data} ->
            io:fwrite(Data),
            User_Name1 = parser(Sockett, User_Name),
            recurser(Sockett, User_Name1);
        {tcp, closed, Sockett} ->
            io:fwrite("tweetclient Cant connect anymore - TCP Closed") 
        end.

beginn() ->
    io:fwrite("\n\n Hii, I am a new tweetclient\n\n"),
    PortNumber = 1204,
    IPAddress = "localhost",
    {ok, Sockett} = gen_tcp:connect(IPAddress, PortNumber, [binary, {packet, 0}]),
    io:fwrite("\n\n Just sent my request to the server\n\n"),
    recurser(Sockett, "_").

parser(Sockett, User_Name) ->
    {ok, [Command_Type]} = io:fread("\nEnter the command: ", "~s\n"),
    io:fwrite(Command_Type),
    if 
        Command_Type == "register" ->
            {ok, [User_Name]} = io:fread("\nEnter the User Name: ", "~s\n"),
            User_Name1 = register_acCounts(Sockett, User_Name);
        Command_Type == "tweet" ->
            if
                User_Name == "_" ->
                    io:fwrite("Please register first!\n"),
                    User_Name1 = parser(Sockett, User_Name);
                true ->
                    Tweet = io:get_line("\nWhat's on your mind?:"),
                    tweet_sender(Sockett,User_Name, Tweet),
                    User_Name1 = User_Name
            end;
        Command_Type == "retweet" ->
            if
                User_Name == "_" ->
                    io:fwrite("Please register first!\n"),
                    User_Name1 = parser(Sockett, User_Name);
                true ->
                    {ok, [Person_User_Name]} = io:fread("\nEnter the User Name whose tweet you want to re-post: ", "~s\n"),
                    Tweet = io:get_line("\nEnter the tweet that you want to repost: "),
                    re_tweet(Sockett, User_Name, Person_User_Name, Tweet),
                    User_Name1 = User_Name
            end;
        Command_Type == "subscribe" ->
            if
                User_Name == "_" ->
                    io:fwrite("Please register first!\n"),
                    User_Name1 = parser(Sockett, User_Name);
                true ->
                    SubscribeUser_Name = io:get_line("\nWho do you want to subscribe to?:"),
                    subscribe_to_user(Sockett, User_Name, SubscribeUser_Name),
                    User_Name1 = User_Name
            end;
        Command_Type == "query" ->
            if
                User_Name == "_" ->
                    io:fwrite("Please register first!\n"),
                    User_Name1 = parser(Sockett, User_Name);
                true ->
                    io:fwrite("\n Querying Options:\n"),
                    io:fwrite("\n 1. My Mentions\n"),
                    io:fwrite("\n 2. Hashtag Search\n"),
                    io:fwrite("\n 3. Subscribed Users Tweets\n"),
                    {ok, [Option]} = io:fread("\nSpecify the task number you want to perform: ", "~s\n"),
                    query_tweet(Sockett, User_Name, Option),
                    User_Name1 = User_Name
            end;
        true ->
            io:fwrite("Invalid command!, Please Enter another command!\n"),
            User_Name1 = parser(Sockett, User_Name)
    end,
    User_Name1.


register_acCounts(Sockett, User_Name) ->
    io:format("SELF: ~p\n", [self()]),
    ok = gen_tcp:send(Sockett, [["register", ",", User_Name, ",", pid_to_list(self())]]),
    io:fwrite("\nAcCounts has been Registered\n"),
    User_Name.



re_tweet(Sockettet, User_Name,Person_User_Name, Tweet) ->
    ok = gen_tcp:send(Sockettet, ["retweet", "," ,Person_User_Name, ",", User_Name,",",Tweet]),
    io:fwrite("\nRetweeted\n").

tweet_sender(Sockett,User_Name, Tweet) ->
    ok = gen_tcp:send(Sockett, ["tweet", "," ,User_Name, ",", Tweet]),
    io:fwrite("\nTweet Sent\n").

subscribe_to_user(Sockett, User_Name, SubscribeUser_Name) ->
    ok = gen_tcp:send(Sockett, ["subscribe", "," ,User_Name, ",", SubscribeUser_Name]),
    io:fwrite("\nSubscribed!\n").

query_tweet(Sockett, User_Name, Option) ->
    if
        Option == "1" ->
            ok = gen_tcp:send(Sockett, ["query", "," ,User_Name, ",", "1"]);
        Option == "2" ->
            Hashtag = io:get_line("\nEnter the hahstag you want to search: "),
            ok = gen_tcp:send(Sockett, ["query", "," ,User_Name, ",","2",",", Hashtag]);
        true ->
            ok = gen_tcp:send(Sockett, ["query", "," ,User_Name, ",", "3"])
    end,
    io:fwrite("Queried related tweets").
