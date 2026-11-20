:- module(test_canonical_node, []).
:- use_module('../../../prolog/web_prolog/node.pl', []).
:- use_module('../../../prolog/web_prolog/pid_utils.pl', []).
:- use_module('../../../prolog/web_prolog/distribution.pl', []).
:- use_module(library(plunit)).
:- dynamic endpoint/2.
:- multifile distribution:hook_ws_endpoint_override/2.
distribution:hook_ws_endpoint_override(Node, Endpoint) :-
    test_canonical_node:endpoint(Node, Endpoint).

:- begin_tests(canonical_node).
test(root_only,
     [forall(member(Input-Expected,[
       'https://node.test/'-'https://node.test',
       'http://node.test:8080/'-'http://node.test:8080',
       'https://[::1]:8443/'-'https://[::1]:8443',
       'https://node.test/path/'-'https://node.test/path/',
       'https://node.test/?x=1'-'https://node.test/?x=1',
       'https://node.test/#part'-'https://node.test/#part']))]) :-
    pid_utils:normalize_node_url(Input,Actual),assertion(Actual==Expected),
    atom_chars(Input,Chars),pid_utils:normalize_node_url(Chars,FromChars),assertion(FromChars==Expected),
    atom_codes(Input,Codes),pid_utils:normalize_node_url(Codes,FromCodes),assertion(FromCodes==Expected).

test(credentials_canonical_key) :-
    node:canonical_peer_tokens(['https://node.test/'-synthetic],Pairs),
    assertion(Pairs==['https://node.test'-synthetic]).
test(distinct_credential_authorities_and_paths) :-
    Pairs=['http://node.test'-a,'https://node.test'-b,
           'https://node.test:444'-c,'https://node.test/path'-d,
           'https://node.test/path/'-e],
    node:canonical_peer_tokens(Pairs,Actual),assertion(Actual==Pairs).
test(conflicting_credentials_before_startup) :-
    catch(node:node(0,[peer_transport_tokens([
      'https://node.test'-'synthetic-secret-a',
      'https://node.test/'-'synthetic-secret-b'])]),Error,true),
    assertion(nonvar(Error)),
    assertion(Error=error(domain_error(peer_transport_tokens,duplicate_node),_)),
    term_string(Error,Text),assertion(\+sub_string(Text,_,_,_,'synthetic-secret')).
test(topology_alias,
     [setup(assertz(test_canonical_node:endpoint('https://canonical.test/','ws://private:3053/ws'))),
      cleanup(retractall(test_canonical_node:endpoint(_,_)))]) :-
    distribution:node_url_to_ws_endpoint('https://canonical.test','ws://private:3053/ws'),
    distribution:node_url_to_ws_endpoint('https://canonical.test/','ws://private:3053/ws'),
    distribution:node_url_to_ws_endpoint('https://canonical.test.invalid','wss://canonical.test.invalid/ws').
test(conflicting_topology,
     [setup((assertz(test_canonical_node:endpoint('https://canonical.test','ws://one/ws')),
             assertz(test_canonical_node:endpoint('https://canonical.test/','ws://two/ws')))),
      cleanup(retractall(test_canonical_node:endpoint(_,_))),
      throws(error(permission_error(redefine,node_endpoint,'https://canonical.test'),_))]) :-
    distribution:node_url_to_ws_endpoint('https://canonical.test/',_).
test(path_topology_distinct,
     [setup((assertz(test_canonical_node:endpoint('https://canonical.test/p','ws://plain/ws')),
             assertz(test_canonical_node:endpoint('https://canonical.test/p/','ws://slash/ws')))),
      cleanup(retractall(test_canonical_node:endpoint(_,_)))]) :-
    distribution:node_url_to_ws_endpoint('https://canonical.test/p','ws://plain/ws'),
    distribution:node_url_to_ws_endpoint('https://canonical.test/p/','ws://slash/ws').
:- end_tests(canonical_node).
