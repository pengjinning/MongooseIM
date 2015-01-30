%%==============================================================================
%% Copyright 2014 Erlang Solutions Ltd.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%==============================================================================
-module(mongoose_api_metrics).

-include("ejabberd.hrl").

%% mongoose_api callbacks
-export([prefix/0,
         routes/0,
         handle_options/2,
         handle_get/2]).

%% internal exports
-export([available_metrics/1,
         sum_metrics/1,
         sum_metric/1,
         host_metric/1,
         host_metrics/1]).

%%--------------------------------------------------------------------
%% mongoose_api callbacks
%%--------------------------------------------------------------------
-spec prefix() -> mongoose_api:prefix().
prefix() ->
    "/metrics".

-spec routes() -> mongoose_api:routes().
routes() ->
    [{"/", [available_metrics]},
     {"/all", [sum_metrics]},
     {"/all/:metric", [sum_metric]},
     {"/host/:host/:metric", [host_metric]},
     {"/host/:host", [host_metrics]}].

-spec handle_options(mongoose_api:bindings(), mongoose_api:options()) ->
    mongoose_api:methods().
handle_options(_Bindings, [_Command]) ->
    [get].

-spec handle_get(mongoose_api:bindings(), mongoose_api:options()) ->
    mongoose_api:response().
handle_get(Bindings, [Command]) ->
    ?MODULE:Command(Bindings).

%%--------------------------------------------------------------------
%% mongoose_api commands actual handlers
%%--------------------------------------------------------------------
available_metrics(_Bindings) ->
    {Hosts, Metrics} = get_available_hosts_metrics(),
    Reply = [{hosts, Hosts}, {metrics, Metrics}],
    {ok, Reply}.

sum_metrics(_Bindings) ->
    Metrics = {metrics, get_sum_metrics()},
    {ok, Metrics}.

sum_metric(Bindings) ->
    {metric, Metric} = lists:keyfind(metric, 1, Bindings),
    try
        case get_sum_metric(binary_to_existing_atom(Metric, utf8)) of
            {error, _, _} ->
                {error, not_found};
            Value ->
                {ok, {metric, Value}}
        end
    catch error:badarg ->
        {error, not_found}
    end.

host_metric(Bindings) ->
    {host, Host} = lists:keyfind(host, 1, Bindings),
    {metric, Metric} = lists:keyfind(metric, 1, Bindings),
    try
        MetricAtom = binary_to_existing_atom(Metric, utf8),
        {ok, Value} = mongoose_metrics:get_metric_value({Host, MetricAtom}),
        {ok, {metric, Value}}
    catch error:badarg ->
        {error, not_found}
    end.

host_metrics(Bindings) ->
    {host, Host} = lists:keyfind(host, 1, Bindings),
    case get_host_metrics(Host) of
        [] ->
            {error, not_found};
        Metrics ->
            {ok, {metrics, Metrics}}
    end.

%%--------------------------------------------------------------------
%% internal functions
%%--------------------------------------------------------------------
-spec get_available_hosts() -> [ejabberd:server()].
get_available_hosts() ->
    ?MYHOSTS.

-spec get_available_metrics(Host :: ejabberd:server()) -> [any()].
get_available_metrics(Host) ->
    mongoose_metrics:get_host_metric_names(Host).

-spec get_available_hosts_metrics() -> {[any(),...], [any()]}.
get_available_hosts_metrics() ->
    Hosts = get_available_hosts(),
    Metrics = get_available_metrics(hd(Hosts)),
    {Hosts, Metrics}.

-spec get_sum_metrics() -> [{_,_}].
get_sum_metrics() ->
    {_Hosts, Metrics} = get_available_hosts_metrics(),
    [{Metric, get_sum_metric(Metric)} || Metric <- Metrics].

-spec get_sum_metric(atom()) -> any().
get_sum_metric(Metric) ->
    mongoose_metrics:get_aggregated_values(Metric).

-spec get_host_metrics('undefined' | ejabberd:server()) -> [{_,_}].
get_host_metrics(Host) ->
    Metrics = mongoose_metrics:get_metric_values(Host),
    [{Name, Value} || {[Host, Name | _], Value} <- Metrics].
