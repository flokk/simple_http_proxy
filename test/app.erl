%% @private
-module (app).

%% API.
-export([start/0]).

%% API.

start() ->
  ok = application:start(crypto),
  ok = application:start(ranch),
  ok = application:start(cowboy),

  Dispatch = cowboy_router:compile([
    {'_', [
      {"/ui", simple_http_proxy, <<"http://flokk-ui-test.herokuapp.com">>}
    ]}
  ]),
  {ok, _} = cowboy:start_http(http, 100, [{port, 8080}], [
    {env, [{dispatch, Dispatch}]}
  ]).
