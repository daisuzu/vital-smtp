let s:suite = themis#suite('SMTP')
let s:assert = themis#helper('assert')

function! s:suite.before() abort
    function! s:sendmail_patched(addr, user, password, from_addr, to_addrs, msg)
        let s:context.args = [a:addr, a:user, a:password, a:from_addr, a:to_addrs, a:msg]

        " {{{ patch
python << endpython
import vim
import smtplib
from mock import MagicMock, patch

context = vim.bindeval("s:context")

mock_method = MagicMock(spec=smtplib.SMTP)
mock_object = MagicMock(spec=smtplib.SMTP)
mock_object.return_value = mock_method
with patch("smtplib.SMTP", mock_object) as mock:
    for c in context.get("mock_object", []):
        if c.keys()[0] == "side_effect":
            # set Exception to smtplib.SMTP()
            mock.side_effect = eval(c.values()[0])
    for c in context.get("mock_method", []):
        if c.values()[0].keys()[0] == "side_effect":
            # set Exception to smtplib.SMTP().xxx()
            getattr(mock.return_value, c.keys()[0]).side_effect = eval(
                c.values()[0].values()[0]
            )

    try:
        vim.command("call s:SMTP.sendmail({args})".format(
            args=", ".join(["'{0}'".format(a) for a in context["args"]])
        ))
    except Exception as exception:
        context.update({"exception": str(exception)})

endpython
        " }}}

        return get(s:context, "exception", "")
    endfunction
endfunction

function! s:suite.before_each() abort
    let s:SMTP = vital#of('vital').import('SMTP')
    let s:context = {'exception': ''}
endfunction

function! s:suite.after_each() abort
    unlet! s:SMTP
endfunction


function! s:suite.test_import() abort
    call s:assert.is_func(get(s:SMTP, 'sendmail', ''))
endfunction

function! s:suite.test_sendmail_success() abort
    let result = s:sendmail_patched('localhost:25', 'user', 'password', 'from_addr', 'to_addrs', 'msg')
    call s:assert.equals(result, "")
endfunction

function! s:suite.test_sendmail_success_without_starttls() abort
    let s:context.mock_method = [
                \     {
                \         "starttls": {
                \             "side_effect": "smtplib.SMTPException('STARTTLS extension not supported by server.')"
                \         }
                \     }
                \ ]
    let result = s:sendmail_patched('localhost:25', 'user', 'password', 'from_addr', 'to_addrs', 'msg')
    call s:assert.equals(result, "")
endfunction

function! s:suite.test_sendmail_success_without_login() abort
    let s:context.mock_method = [
                \     {
                \         "login": {
                \             "side_effect": "smtplib.SMTPException('SMTP AUTH extension not supported by server.')"
                \         }
                \     }
                \ ]
    let result = s:sendmail_patched('localhost:25', 'user', 'password', 'from_addr', 'to_addrs', 'msg')
    call s:assert.equals(result, "")
endfunction

function! s:suite.test_sendmail_failed_to_connect() abort
    let s:context.mock_object = [
                \     {
                \         "side_effect": "Exception('Connection refused')"
                \     }
                \ ]
    let result = s:sendmail_patched('localhost:25', 'user', 'password', 'from_addr', 'to_addrs', 'msg')
    call s:assert.equals(result, "Vital-SMTP.sendmail(): Connection refused")
endfunction

function! s:suite.test_sendmail_failed_to_starttls() abort
    let s:context.mock_method = [
                \     {
                \         "starttls": {
                \             "side_effect": "RuntimeError('No SSL support included in this Python')"
                \         }
                \     }
                \ ]
    let result = s:sendmail_patched('localhost:25', 'user', 'password', 'from_addr', 'to_addrs', 'msg')
    call s:assert.equals(result, "Vital-SMTP.sendmail(): No SSL support included in this Python")
endfunction

function! s:suite.test_sendmail_failed_to_login() abort
    let s:context.mock_method = [
                \     {
                \         "login": {
                \             "side_effect": "smtplib.SMTPAuthenticationError(530, 'Authentication required')"
                \         }
                \     }
                \ ]
    let result = s:sendmail_patched('localhost:25', 'user', 'password', 'from_addr', 'to_addrs', 'msg')
    call s:assert.equals(result, "Vital-SMTP.sendmail(): (530, 'Authentication required')")
endfunction

function! s:suite.test_sendmail_failed_to_send() abort
    let s:context.mock_method = [
                \     {
                \         "sendmail": {
                \             "side_effect": "smtplib.SMTPDataError(510, 'Bad email address')"
                \         }
                \     }
                \ ]
    let result = s:sendmail_patched('localhost:25', 'user', 'password', 'from_addr', 'to_addrs', 'msg')
    call s:assert.equals(result, "Vital-SMTP.sendmail(): (510, 'Bad email address')")
endfunction

function! s:suite.test_sendmail_failed_to_quit() abort
    let s:context.mock_method = [
                \     {
                \         "quit": {
                \             "side_effect": "smtplib.SMTPServerDisconnected('Server not connected')"
                \         }
                \     }
                \ ]
    let result = s:sendmail_patched('localhost:25', 'user', 'password', 'from_addr', 'to_addrs', 'msg')
    call s:assert.equals(result, "Vital-SMTP.sendmail(): Server not connected")
endfunction

" vim: foldmethod=marker
