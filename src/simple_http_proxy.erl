%%
%% simple_http_proxy.erl
%%
-module (simple_http_proxy).

-export([init/3]).
-export([handle/2]).
-export([terminate/3]).

-record (state, {
  client,
  url
}).

init(_Transport, Req, Url) when is_binary(Url) ->
  {ok, Client} = cowboy_client:init([]),
  {ok, Req, #state{client=Client, url=Url}}.

handle(Req, #state{client=Client, url=Url}=State) ->
  {Method, Req} = cowboy_req:method(Req),
  {Headers, Req} = cowboy_req:headers(Req),
  {PathInfo, Req} = cowboy_req:path_info(Req),
  {FullPath, Req} = cowboy_req:path(Req),
  {Query, Req} = cowboy_req:qs(Req),
  {Port, Req} = cowboy_req:port(Req),
  {Host, Req} = cowboy_req:host(Req),
  {HostUrl, Req} = cowboy_req:host_url(Req),

  Proto = case HostUrl of
    <<"https",_>> -> <<"https">>;
    _ -> <<"http">>
  end,

  %% Setup the request info
  ReqPath = binary_join([<<>>|PathInfo], <<"/">>),
  [MountPath, TrailingSlash] = binary:split(FullPath, ReqPath),

  ReqUrl = <<Url/binary,ReqPath/binary,TrailingSlash/binary,"?",Query/binary>>,

  ReqHeaders = [
    {<<"x-forwarded-proto">>, Proto},
    {<<"x-forwarded-host">>, Host},
    {<<"x-forwarded-path">>, MountPath},
    {<<"x-forwarded-port">>, list_to_binary(integer_to_list(Port))}
  |proplists:delete(<<"connection">>, Headers)],

  {ok, Client2} = cowboy_client:request(Method, ReqUrl, ReqHeaders, Client),
  {ok, Status, ResHeaders, Client3} = cowboy_client:response(Client2),

  {ok, Req2} = cowboy_req:chunked_reply(Status, ResHeaders, Req),

  stream_body(Req2, Client3),

  {ok, Req2, State}.


stream_body(Req, Client) ->
  case cowboy_client:stream_body(Client) of
    {ok, Data} ->
      lager:debug("proxy sending data ~p", [Data]),
      ok = cowboy_req:chunk(Data, Req),
      cowboy_client:stream_body(Client);
    {done, Client} ->
      lager:debug("proxy finished streaming"),
      ok;
    _ ->
      ok
  end.

terminate(_Reason, _Req, _State) ->
  ok.

binary_join([], _Sep) ->
  <<>>;
binary_join([H], _Sep) ->
  << H/binary >>;
binary_join([H | T], Sep) ->
  << H/binary, Sep/binary, (binary_join(T, Sep))/binary >>.
