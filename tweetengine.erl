-module(tweetengine).
-import(maps, []).
-export[beginn/0].

sendMessage(Sockettet, Client_Sockettet_Mapping, Tweet, Subscribers, User_Name) ->
    if
        Subscribers == [] ->
            io:fwrite("\nNo followers!\n");
        true ->

            [Client_To_Send | Remaining_List ] = Subscribers,
            io:format("Client to send: ~p\n", [Client_To_Send]),
            io:format("\nRemaining List: ~p~n",[Remaining_List]),
            Client_Sockettet_Row = ets:lookup(Client_Sockettet_Mapping,Client_To_Send),
            Val3 = lists:nth(1, Client_Sockettet_Row),
            Client_Sockettet = element(2, Val3),
            io:format("\nClient Sockettet: ~p~n",[Client_Sockettet]),
            
            ok = gen_tcp:send(Client_Sockettet, ["New tweet received!\n",User_Name,":",Tweet]),
            ok = gen_tcp:send(Sockettet, "Your tweet has been sent"),
            
            sendMessage(Sockettet, Client_Sockettet_Mapping, Tweet, Remaining_List, User_Name)
    end,
    io:fwrite("Send message!\n").

await_connections(Listen, Table_Store, Client_Sockettet_Mapping) ->
    {ok, Sockettet} = gen_tcp:accept(Listen),
    ok = gen_tcp:send(Sockettet, "YES"),
    spawn(fun() -> await_connections(Listen, Table_Store, Client_Sockettet_Mapping) end),
    receiving_do(Sockettet, Table_Store, [], Client_Sockettet_Mapping).

beginn() ->
    io:fwrite("\n\n Tweet Clone Engine!!! \n\n"),
    Table_Store = ets:new(messages, [ordered_set, named_Table_Store, public]),
    Client_Sockettet_Mapping = ets:new(clients, [ordered_set, named_Table_Store, public]),
    {ok, ListenSockettet} = gen_tcp:listen(1204, [binary, {keepalive, true}, {reuseaddr, true}, {active, false}]),
    await_connections(ListenSockettet, Table_Store, Client_Sockettet_Mapping).



receiving_do(Sockettet, Table_Store, Bs, Client_Sockettet_Mapping) ->
    io:fwrite("Received Do!!\n\n"),
    case gen_tcp:recv(Sockettet, 0) of
        {ok, Data1} ->
            
            Data = re:split(Data1, ","),
            Type = binary_to_list(lists:nth(1, Data)),

            io:format("\n\nData: ~p\n\n ", [Data]),
            io:format("\n\nType: ~p\n\n ", [Type]),

            if 
                Type == "register" ->
                    User_Name = binary_to_list(lists:nth(2, Data)),
                    PID = binary_to_list(lists:nth(3, Data)),
                    io:format("\nPID:~p\n", [PID]),
                    io:format("\nSockettet:~p\n", [Sockettet]),
                    io:format("Type: ~p\n", [Type]),
                    io:format("\n~p want to receive an account\n", [User_Name]),
                    
                    Output = ets:lookup(Table_Store, User_Name),
                    io:format("output: ~p\n", [Output]),
                    if
                        Output == [] ->

                            ets:insert(Table_Store, {User_Name, [{"followers", []}, {"tweets", []}]}),      
                            ets:insert(Client_Sockettet_Mapping, {User_Name, Sockettet}),                
                            Temp_List = ets:lookup(Table_Store, User_Name),
                            io:format("~p", [lists:nth(1, Temp_List)]),

                          
                            ok = gen_tcp:send(Sockettet, "User has been registered"), % RESPOND BACK - YES/NO
                            io:fwrite("Key_Value isn't in the database\n");
                        true ->
                            ok = gen_tcp:send(Sockettet, "User_Name already taken! Please run the command again with a new User_Name"),
                            io:fwrite("Duplicate Key_Value found!\n")
                    end,
                    receiving_do(Sockettet, Table_Store, [User_Name], Client_Sockettet_Mapping);

                Type == "tweet" ->
                    User_Name = binary_to_list(lists:nth(2, Data)),
                    Tweet = binary_to_list(lists:nth(3, Data)),
                    io:format("\n ~p the following tweet has been sent: ~p", [User_Name, Tweet]),
                    Val = ets:lookup(Table_Store, User_Name),
                    io:format("Output: ~p\n", [Val]),
                    Val3 = lists:nth(1, Val),
                    Val2 = element(2, Val3),
                    Val1 = maps:from_list(Val2),
                    {ok, CurrentFollowers} = maps:find("followers",Val1),                         
                    {ok, CurrentTweets} = maps:find("tweets",Val1),

                    NewTweets = CurrentTweets ++ [Tweet],
                    io:format("~p~n",[NewTweets]),
                    
                    ets:insert(Table_Store, {User_Name, [{"followers", CurrentFollowers}, {"tweets", NewTweets}]}),

                    Output_After_Tweet = ets:lookup(Table_Store, User_Name),
                    io:format("\nOutput after tweeting: ~p\n", [Output_After_Tweet]),
                  
                    sendMessage(Sockettet, Client_Sockettet_Mapping, Tweet, CurrentFollowers, User_Name),
                    receiving_do(Sockettet, Table_Store, [User_Name], Client_Sockettet_Mapping);

                Type == "retweet" ->
                    Person_User_Name = binary_to_list(lists:nth(2, Data)),
                    User_Name = binary_to_list(lists:nth(3, Data)),
                    Sub_User = string:strip(Person_User_Name, right, $\n),
                    io:format("Retweet from: ~p\n", [Sub_User]),
                    Tweet = binary_to_list(lists:nth(4, Data)),
                    Out = ets:lookup(Table_Store, Sub_User),
                    if
                        Out == [] ->
                            io:fwrite("User not found!\n");
                        true ->
                            Out1 = ets:lookup(Table_Store, User_Name),
                            Val3 = lists:nth(1, Out1),
                            Val2 = element(2, Val3),
                            Val1 = maps:from_list(Val2),
                            Val_3 = lists:nth(1, Out),
                            Val_2 = element(2, Val_3),
                            Val_1 = maps:from_list(Val_2),
                            {ok, CurrentFollowers} = maps:find("followers",Val1),
                            {ok, CurrentTweets} = maps:find("tweets",Val_1),
                            io:format("Reposting the Tweet: ~p\n", [Tweet]),
                            CheckTweet = lists:member(Tweet, CurrentTweets),
                            if
                                CheckTweet == true ->
                                    NewTweet = string:concat(string:concat(string:concat("re:",Sub_User),"->"),Tweet),
                                    sendMessage(Sockettet, Client_Sockettet_Mapping, NewTweet, CurrentFollowers, User_Name);
                                true ->
                                    io:fwrite("Tweet does not exist!\n")
                            end     
                    end,
                    io:format("\n ~p wants to retweet", [User_Name]),
                    receiving_do(Sockettet, Table_Store, [User_Name], Client_Sockettet_Mapping);

                Type == "subscribe" ->
                    User_Name = binary_to_list(lists:nth(2, Data)),
                    SubscribedUser_Name = binary_to_list(lists:nth(3, Data)),
                    Sub_User = string:strip(SubscribedUser_Name, right, $\n),

                    Output1 = ets:lookup(Table_Store, Sub_User),

                    if
                        Output1 == [] ->
                            io:fwrite("The User_Name not found. \n");
                        true ->

                            Val = ets:lookup(Table_Store, Sub_User),
                            Val3 = lists:nth(1, Val),
                            Val2 = element(2, Val3),

                            Val1 = maps:from_list(Val2),                            
                            {ok, CurrentFollowers} = maps:find("followers",Val1),
                            {ok, CurrentTweets} = maps:find("tweets",Val1),

                            NewFollowers = CurrentFollowers ++ [User_Name],
                            io:format("~p~n",[NewFollowers]),
                        
                            ets:insert(Table_Store, {Sub_User, [{"followers", NewFollowers}, {"tweets", CurrentTweets}]}),

                            Output2 = ets:lookup(Table_Store, Sub_User),
                            io:format("\noutput after subscribing: ~p\n", [Output2]),

                            ok = gen_tcp:send(Sockettet, "subscribed!"),

                            receiving_do(Sockettet, Table_Store, [User_Name], Client_Sockettet_Mapping)
                    end,
                    io:format("\n ~p wants to subscribe to ~p\n", [User_Name, Sub_User]),
                    
                    ok = gen_tcp:send(Sockettet, "Subscribed!"),
                    receiving_do(Sockettet, Table_Store, [User_Name], Client_Sockettet_Mapping);

                Type == "query" ->
                    Option = binary_to_list(lists:nth(3, Data)),
                    User_Name = binary_to_list(lists:nth(2, Data)),
                    io:format("Query: The current User_Name is -> ~p\n", [User_Name]),
                    if
                        Option == "1" ->
                            io:fwrite("My mentions!\n");
                        Option == "2" ->
                            io:fwrite("Hashtag Search\n"),
                            Hashtag = binary_to_list(lists:nth(4, Data)),
                            io:format("Hashtag: ~p\n", [Hashtag]);
                        true ->
                            io:fwrite("Subscribed User Search\n"),
                            Sub_User_Name = ets:first(Table_Store),
                            Sub_User = string:strip(Sub_User_Name, right, $\n),
                            io:format("Sub_User_Name: ~p\n", [Sub_User]),
                            Val = ets:lookup(Table_Store, Sub_User),
                            Val3 = lists:nth(1, Val),
                            Val2 = element(2, Val3),
                            Val1 = maps:from_list(Val2),                            
                            {ok, CurrentTweets} = maps:find("tweets",Val1),
                            io:format("\n ~p : ", [Sub_User]),
                            io:format("~p~n",[CurrentTweets]),
                            searchWholeTable_Store(Table_Store, Sub_User, User_Name)        
                    end,
                    io:format("\n ~p wants to query", [User_Name]),
                    receiving_do(Sockettet, Table_Store, [User_Name], Client_Sockettet_Mapping);
                true ->
                    io:fwrite("\n Other Things!")
            end;

        {error, closed} ->
            {ok, list_to_binary(Bs)};
        {error, Reason} ->
            io:fwrite("error"),
            io:fwrite(Reason)
    end.




searchWholeTable_Store(Table_Store, Key_Value, User_Name) ->
    CurrentRow_Key_Value = ets:next(Table_Store, Key_Value),
    Val = ets:lookup(Table_Store, CurrentRow_Key_Value),
    Val3 = lists:nth(1, Val),
    Val2 = element(2, Val3),
    Val1 = maps:from_list(Val2),                            
    {ok, CurrentFollowers} = maps:find("followers",Val1),
    IsMember = lists:member(User_Name, CurrentFollowers),
    if
        IsMember == true ->
            {ok, CurrentTweets} = maps:find("tweets",Val1),
            io:format("\n ~p : ", [CurrentRow_Key_Value]),
            io:format("~p~n",[CurrentTweets]),
            searchWholeTable_Store(Table_Store, CurrentRow_Key_Value, User_Name);
        true ->
            io:fwrite("\n No more tweets!\n")
    end,
    io:fwrite("\n Searching the whole Table_Store!\n").