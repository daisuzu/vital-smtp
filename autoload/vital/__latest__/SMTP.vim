let s:save_cpo = &cpo
set cpo&vim


let s:_smtp = {
      \    'host': '',
      \    'port': 0,
      \ }

function! s:sendmail(addr, user, password, from_addr, to_addrs, msg)
  let if_obj = deepcopy(s:_smtp)

  if type(a:addr) == type({})
    call extend(if_obj, a:addr)
  elseif type(a:addr) == type('')
    let if_obj.host = a:addr
  endif

  let if_obj.user = a:user
  let if_obj.password = a:password

  let if_obj.from_addr = a:from_addr
  let if_obj.to_addrs = a:to_addrs
  let if_obj.msg = a:msg

python << endpython
try:
    class DummyClassForLocalScope:
        def main():
            import vim, smtplib

            if_obj = vim.bindeval('if_obj')

            try:
                smtp = smtplib.SMTP(if_obj['host'], if_obj['port'])
            except Exception as exception:
                if_obj.update({'exception': str(exception)})
                return

            try:
                smtp.starttls()
            except smtplib.SMTPException as exception:
                # Server does not support STARTTLS
                pass
            except RuntimeError as exception:
                # Python does not support SSL
                if_obj.update({'exception': str(exception)})
                return
            except Exception as exception:
                if_obj.update({'exception': str(exception)})
                return

            try:
                if if_obj['user'] and if_obj['password']:
                    smtp.login(if_obj['user'], if_obj['password'])
            except smtplib.SMTPAuthenticationError as exception:
                # Authentication error
                # NOTE: Need to raise SMTPAuthenticationError before SMTPException
                if_obj.update({'exception': str(exception)})
                return
            except smtplib.SMTPException as exception:
                # Server does not support SMTP-AUTH
                pass
            except Exception as exception:
                if_obj.update({'exception': str(exception)})
                return

            try:
                smtp.sendmail(
                    if_obj['from_addr'],
                    if_obj['to_addrs'],
                    if_obj['msg'],
                )
            except Exception as exception:
                if_obj.update({'exception': str(exception)})
                return

            try:
                smtp.quit()
            except Exception as exception:
                if_obj.update({'exception': str(exception)})
                return


        main()
        raise RuntimeError('Exit from local scope')

except RuntimeError as exception:
    if exception.args != ('Exit from local scope',):
        raise exception

endpython

  if get(if_obj, 'exception', '') != ''
    throw 'Vital-SMTP.sendmail(): ' . if_obj.exception
  endif

endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set et ts=2 sts=2 sw=2 tw=0:
