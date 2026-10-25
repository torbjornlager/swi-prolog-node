% Pure validation only. No provider or service request is invoked.
:- module(service_text_boundary,[run/0]).
:- consult('../../../load.pl').
:- use_module('../../../prolog/web_prolog/text_config.pl').
:- use_module(library(http/json)).
:- use_module(library(readutil)).
run :-
    getenv('WP_AUDIT_DEMONSTRATOR_ROOT',Root),
    directory_file_path(Root,'examples/services/model_service.pl',Model),
    directory_file_path(Root,'examples/services/jev_service.pl',Jev),
    use_module(Model,[]),use_module(Jev,[]),
    text_double_quotes(Mode),
    read_term_from_atom('"hi"',Text,[double_quotes(Mode)]),
    (model_service:message_text(Text,500,_) -> ModelResult=accepted ; ModelResult=rejected),
    (jev_service:valid_text(Text) -> JevResult=accepted ; JevResult=rejected),
    system:format(string(Native),'~w',[hi]),
    (model_service:message_text(Native,500,_) -> NativeModel=accepted ; NativeModel=rejected),
    (jev_service:valid_text(Native) -> NativeJev=accepted ; NativeJev=rejected),
    json_write_dict(current_output,json{mode:Mode,model_reader_input:ModelResult,
       jev_reader_input:JevResult,native_model_control:NativeModel,native_jev_control:NativeJev,
       provider_called:false}),nl.
