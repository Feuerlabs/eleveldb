%% -------------------------------------------------------------------
%%
%%  e_leveldb: Erlang Wrapper for LevelDB (http://code.google.com/p/leveldb/)
%%
%% Copyright (c) 2010 Basho Technologies, Inc. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
-module(e_leveldb).

-export([open/2,
         get/3,
         put/4,
         delete/3,
         write/3,
         fold/4,
         status/2,
         destroy/2,
         repair/2]).

-export([snapshot/1,
         snapshot_close/1]).

-export([iterator/2,
         iterator_move/2,
         iterator_close/1]).

-on_load(init/0).

-ifdef(TEST).
-ifdef(EQC).
-include_lib("eqc/include/eqc.hrl").
-define(QC_OUT(P),
        eqc:on_output(fun(Str, Args) -> io:format(user, Str, Args) end, P)).
-endif.
-include_lib("eunit/include/eunit.hrl").
-endif.

-spec init() -> ok | {error, any()}.
init() ->
    SoName = case code:priv_dir(?MODULE) of
                 {error, bad_name} ->
                     case code:which(?MODULE) of
                         Filename when is_list(Filename) ->
                             filename:join([filename:dirname(Filename),"../priv", "e_leveldb"]);
                         _ ->
                             filename:join("../priv", "e_leveldb")
                     end;
                 Dir ->
                     filename:join(Dir, "e_leveldb")
             end,
    erlang:load_nif(SoName, 0).

-type open_options() :: [{create_if_missing, boolean()} |
                         {error_if_exists, boolean()} |
                         {write_buffer_size, pos_integer()} |
                         {max_open_files, pos_integer()} |
                         {block_size, pos_integer()} |
                         {block_restart_interval, pos_integer()} |
                         {cache_size, pos_integer()} |
                         {paranoid_checks, boolean()}].

-type read_options() :: [{verify_checksums, boolean()} |
                         {fill_cache, boolean()}].

-type write_options() :: [{sync, boolean()} |
                          {return_snapshot, boolean()}].

-type write_actions() :: [{put, Key::binary(), Value::binary()} |
                          {delete, Key::binary()} |
                          clear].

-type iterator_action() :: first | last | next | prev | binary().

-opaque db_ref() :: binary().

-opaque itr_ref() :: binary().

-opaque snapshot_ref() :: binary().

-type read_ref() :: db_ref() | snapshot_ref().

-type write_result() :: ok | {ok, snapshot_ref()} | {error, any()}.

-spec open(string(), open_options()) -> {ok, db_ref()} | {error, any()}.
open(_Name, _Opts) ->
    erlang:nif_error({error, not_loaded}).

-spec get(read_ref(), binary(), read_options()) -> {ok, binary()} | not_found | {error, any()}.
get(_Ref, _Key, _Opts) ->
    erlang:nif_error({error, not_loaded}).

-spec put(db_ref(), binary(), binary(), write_options()) -> write_result().
put(Ref, Key, Value, Opts) ->
    write(Ref, [{put, Key, Value}], Opts).

-spec delete(db_ref(), binary(), write_options()) -> write_result().
delete(Ref, Key, Opts) ->
    write(Ref, [{delete, Key}], Opts).

-spec write(db_ref(), write_actions(), write_options()) -> write_result().
write(_Ref, _Updates, _Opts) ->
    erlang:nif_error({error, not_loaded}).

-spec iterator(read_ref(), read_options()) -> {ok, itr_ref()}.
iterator(_Ref, _Opts) ->
    erlang:nif_error({error, not_loaded}).

-spec iterator_move(itr_ref(), iterator_action()) -> {ok, Key::binary(), Value::binary()} |
                                                     {error, invalid_iterator} |
                                                     {error, iterator_closed}.
iterator_move(_IRef, _Loc) ->
    erlang:nif_error({error, not_loaded}).


-spec iterator_close(itr_ref()) -> ok.
iterator_close(_IRef) ->
    erlang:nif_error({error, not_loaded}).

-spec snapshot(db_ref()) -> {ok, snapshot_ref()}.
snapshot(_DBRef) ->
    erlang:nif_error({error, not_loaded}).

-spec snapshot_close(snapshot_ref()) -> ok.
snapshot_close(_SRef) ->
    erlang:nif_error({error, not_loaded}).    

-type fold_fun() :: fun(({Key::binary(), Value::binary()}, any()) -> any()).

-spec fold(read_ref(), fold_fun(), any(), read_options()) -> any().
fold(Ref, Fun, Acc0, Opts) ->
    {ok, Itr} = iterator(Ref, Opts),
    try
        fold_loop(iterator_move(Itr, first), Itr, Fun, Acc0)
    after
        iterator_close(Itr)
    end.

-spec status(db_ref(), Key::binary()) -> {ok, binary()} | error.
status(_Ref, _Key) ->
    erlang:nif_error({error, not_loaded}).

destroy(_Name, _Opts) ->
    ok.

repair(_Name, _Opts) ->
    ok.

%% ===================================================================
%% Internal functions
%% ===================================================================
fold_loop({error, invalid_iterator}, _Itr, _Fun, Acc0) ->
    Acc0;
fold_loop({ok, K, V}, Itr, Fun, Acc0) ->
    Acc = Fun({K, V}, Acc0),
    fold_loop(iterator_move(Itr, next), Itr, Fun, Acc).

%% ===================================================================
%% EUnit tests
%% ===================================================================
-ifdef(TEST).

open_test() ->
    os:cmd("rm -rf /tmp/eleveldb.open.test"),
    {ok, Ref} = open("/tmp/eleveldb.open.test", [{create_if_missing, true}]),
    ok = ?MODULE:put(Ref, <<"abc">>, <<"123">>, []),
    {ok, <<"123">>} = ?MODULE:get(Ref, <<"abc">>, []),
    not_found = ?MODULE:get(Ref, <<"def">>, []).

snapshot_test() ->
    os:cmd("rm -rf /tmp/eleveldb.snapshot.test"),
    {ok, Ref} = open("/tmp/eleveldb.snapshot.test", [{create_if_missing, true}]),
    ok = ?MODULE:put(Ref, <<"1">>, <<"1">>, []),
    {ok, Snapshot} = ?MODULE:snapshot(Ref),
    ok = ?MODULE:put(Ref, <<"2">>, <<"2">>, []),   
    {ok, _} = ?MODULE:get(Ref, <<"2">>, []),
    not_found = ?MODULE:get(Snapshot, <<"2">>, []),
    {ok, WriteSnapshot} = ?MODULE:put(Ref, <<"3">>, <<"4">>, [{return_snapshot, true}]),
    {ok, _} = ?MODULE:get(WriteSnapshot, <<"3">>, []),
    {error, read_only_snapshot} = ?MODULE:put(WriteSnapshot, <<"4">>, <<"5">>, []),
    ?MODULE:snapshot_close(Snapshot),
    ?MODULE:snapshot_close(WriteSnapshot).

fold_test() ->
    os:cmd("rm -rf /tmp/eleveldb.fold.test"),
    {ok, Ref} = open("/tmp/eleveldb.fold.test", [{create_if_missing, true}]),
    ok = ?MODULE:put(Ref, <<"def">>, <<"456">>, []),
    ok = ?MODULE:put(Ref, <<"abc">>, <<"123">>, []),
    ok = ?MODULE:put(Ref, <<"hij">>, <<"789">>, []),
    [{<<"abc">>, <<"123">>},
     {<<"def">>, <<"456">>},
     {<<"hij">>, <<"789">>}] = lists:reverse(fold(Ref, fun({K, V}, Acc) -> [{K, V} | Acc] end,
                                                  [], [])),
    {ok, Snapshot} = ?MODULE:snapshot(Ref),
    ok = ?MODULE:put(Ref, <<"klm">>, <<"012">>, []),
    [{<<"abc">>, <<"123">>},
     {<<"def">>, <<"456">>},
     {<<"hij">>, <<"789">>}] = lists:reverse(fold(Snapshot, fun({K, V}, Acc) -> [{K, V} | Acc] end,
                                                  [], [])).
    
-ifdef(EQC).

qc(P) ->
    ?assert(eqc:quickcheck(?QC_OUT(P))).

keys() ->
    eqc_gen:non_empty(list(eqc_gen:non_empty(binary()))).

values() ->
    eqc_gen:non_empty(list(binary())).

ops(Keys, Values) ->
    {oneof([put, delete]), oneof(Keys), oneof(Values)}.

apply_kv_ops([], _Ref, Acc0) ->
    Acc0;
apply_kv_ops([{put, K, V} | Rest], Ref, Acc0) ->
    ok = e_leveldb:put(Ref, K, V, []),
    apply_kv_ops(Rest, Ref, orddict:store(K, V, Acc0));
apply_kv_ops([{delete, K, _} | Rest], Ref, Acc0) ->
    ok = e_leveldb:delete(Ref, K, []),
    apply_kv_ops(Rest, Ref, orddict:store(K, deleted, Acc0)).

prop_put_delete() ->
    ?LET({Keys, Values}, {keys(), values()},
         ?FORALL(Ops, eqc_gen:non_empty(list(ops(Keys, Values))),
                 begin
                     ?cmd("rm -rf /tmp/eleveldb.putdelete.qc"),
                     {ok, Ref} = e_leveldb:open("/tmp/eleveldb.putdelete.qc",
                                                [{create_if_missing, true}]),
                     Model = apply_kv_ops(Ops, Ref, []),

                     %% Valdiate that all deleted values return not_found
                     F = fun({K, deleted}) ->
                                 ?assertEqual(not_found, e_leveldb:get(Ref, K, []));
                            ({K, V}) ->
                                 ?assertEqual({ok, V}, e_leveldb:get(Ref, K, []))
                         end,
                     lists:map(F, Model),
                     
                     %% Validate that a fold returns sorted values
                     Actual = lists:reverse(fold(Ref, fun({K, V}, Acc) -> [{K, V} | Acc] end,
                                                 [], [])),
                     ?assertEqual([{K, V} || {K, V} <- Model, V /= deleted],
                                  Actual),
                     true
                 end)).

prop_put_delete_test_() ->
    {timeout, 3*60, fun() -> qc(prop_put_delete()) end}.



-endif.

-endif.
