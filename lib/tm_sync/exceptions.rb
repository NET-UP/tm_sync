module TmSync

  class ConnectionBrokenException < Exception; end
  class InvalidCredentialsException < Exception; end
  class RemoteVersionUnsupported < Exception; end
  class UnexpectedResponseException < Exception; end

end