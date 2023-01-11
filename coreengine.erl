-module(coreengine).
-export[beginn/0].

createtweet(Counts, Num_Tweets, Maximum_Subs, Main_Table_Store) ->    
    User_Name = Counts,
    Tweets_Num = round(floor(Maximum_Subs/Counts)),
    Subscribe_Num = round(floor(Maximum_Subs/(Num_Tweets-Counts+1))) - 1,

    PID = spawn(tweetclient, test, [User_Name, Tweets_Num, Subscribe_Num, false]),

    ets:insert(Main_Table_Store, {User_Name, PID}),
    if 
        Counts == Num_Tweets ->
            ok;
        true ->
            createtweet(Counts+1, Num_Tweets, Maximum_Subs, Main_Table_Store)
    end.

beginn() ->
    io:fwrite("\n\n coreengine Running\n\n"),
    
    {ok, [Num_Inputtweets]} = io:fread("\nNumber of tweetclients to simulate: ", "~s\n"),
    {ok, [Max_InputSubscribers]} = io:fread("\nMaximum Number of Subscribers a tweetclient can have: ", "~s\n"),
    {ok, [Disconnecttweet_Inputs]} = io:fread("\nPercentage of tweetclients to disconnect to simulate periods of live connection and disconnection ", "~s\n"),

    Num_Tweets = list_to_integer(Num_Inputtweets),
    MaxSubscribers = list_to_integer(Max_InputSubscribers),
    Disconnecttweetclients = list_to_integer(Disconnecttweet_Inputs),
    tweetclientsToDisconnect = Disconnecttweetclients * (0.01) * Num_Tweets,

    Main_Table_Store = ets:new(messages, [ordered_set, named_Table_Store, public]),
    createtweet(1, Num_Tweets, MaxSubscribers, Main_Table_Store),
    beginn_Time = erlang:system_time(millisecond),
    End_Time = erlang:system_time(millisecond),
    io:format("\nTime Taken to Converge: ~p milliseconds\n", [End_Time - beginn_Time]).




