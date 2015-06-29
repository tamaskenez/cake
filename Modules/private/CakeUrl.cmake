if(NOT CAKE_URL_INCLUDED)
  set(CAKE_URL_INCLUDED 1)

  # creates urls like github.com/dir/a from https://user:psw@github.com:123/dir/a.git
  # works for git@github.com:a/b, too
  # returns ans
  function(cake_get_humanish_part_of_url url)
    string(REGEX REPLACE "^[a-zA-Z][a-zA-Z0-9+.-]*:" "" ans "${url}") # strip leading scheme information
    string(REGEX REPLACE "^/+" "" ans "${ans}") # strip leading slashes
    string(REGEX REPLACE "^[^@]*@" "" ans "${ans}") # strip leading userinfo
    string(REGEX REPLACE ":[0-9]+/" "/" ans "${ans}") # remove port
    string(REGEX REPLACE "/+$" "" ans "${ans}") # strip trailing slashes
    string(REGEX REPLACE "\\.git$" "" ans "${ans}") # strip trailing .git
    string(REGEX REPLACE "/+$" "" ans "${ans}") # strip trailing slashes
    set(ans "${ans}" PARENT_SCOPE)
  endfunction()


  # strips URL scheme, .git extension, splits trailiing :commitish
  # for an input url like http://user:psw@a.b.com/c/d/e.git?branch=release/2.3&-DWITH_SQLITE=1&-DBUILD_SHARED_LIBS=1
  # we need the following parts:
  # repo_url: http://user:psw@a.b.com/c/d/e.git
  #   this is used for git clone
  # repo_url_cid: a_b_com_c_d_e (scheme, user:psw@ and .git stripped, made c identifier)
  #   this identifies a repo and also the name of directory of the local copy
  # options: "branch=release/2.3" list of the query items that do not begin with -D
  # definitions: "-DWITH_SQLITE=1;-DBUILD_SHARED_LIBS=1" list of the query items that begins with -D
  #   used for passing build parameters to the package, like autoconf's --with... and macports' variants
  function(cake_parse_pkg_url URL REPO_URL_OUT REPO_URL_CID_OUT OPTIONS_OUT DEFINITIONS_OUT)

    string(REGEX MATCH "^([^?]+)\\??(.*)$" _ "${URL}")
    set(repo_url "${CMAKE_MATCH_1}")
    set(query "${CMAKE_MATCH_2}")

    string(REPLACE "&" ";" query "${query}")

    cake_get_humanish_part_of_url("${repo_url}")
    string(MAKE_C_IDENTIFIER "${ans}" repo_url_cid)

    set(options "")
    set(definitions "")
    foreach(i ${query})
      if(i MATCHES "^([^=]+)=(.*)$")
        if(CMAKE_MATCH_1 MATCHES "^-D?") # -D and at least one character
          string(REPLACE ";" "\;" i "${i}")
          list(APPEND definitions "${i}")
        else()
          list(APPEND options "${i}")
        endif()
      else()
        message(FATAL_ERROR "[cake] Invalid item (${i}) in URL query string, URL: ${URL}")
      endif()
    endforeach()

    set(${REPO_URL_OUT} "${repo_url}" PARENT_SCOPE)
    set(${REPO_URL_CID_OUT} "${repo_url_cid}" PARENT_SCOPE)
    set(${OPTIONS_OUT} "${options}" PARENT_SCOPE)
    set(${DEFINITIONS_OUT} "${definitions}" PARENT_SCOPE)
  endfunction()
endif()
