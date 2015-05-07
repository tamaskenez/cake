if(NOT CAKE_REPO_DB_INCLUDED)
  set(CAKE_REPO_DB_INCLUDED 1)

  # db.txt is a sequence of \t<primary-key><field>=<value> strings
  # where <primary-key> is a decimal positive integer (>0)
  # <field> is a c-identifier-like field name
  # <value> is an arbitrary text not containing \t
  # db_next_pk.txt contains a single number, the next primary key
  # They are cached internally in cache-internal variables CAKE_REPO_DB and CAKE_REPO_DB_NEXT_PK

  macro(cake_repo_db_save_db)
    file(WRITE "${CAKE_PKG_REPOS_DIR}/db.txt" "${CAKE_REPO_DB}")
  endmacro()

  macro(cake_repo_db_save_next_pk)
    file(WRITE "${CAKE_PKG_REPOS_DIR}/db_next_pk.txt" "${CAKE_REPO_DB_NEXT_PK}")
  endmacro()

  macro(cake_repo_db_save)
    cake_repo_db_save_db()
    cake_repo_db_save_next_pk()
  endmacro()

  macro(cake_repo_db_load)
    if(EXISTS "${CAKE_PKG_REPOS_DIR}/db.txt" AND EXISTS "${CAKE_PKG_REPOS_DIR}/db_next_pk.txt")
      file(READ "${CAKE_PKG_REPOS_DIR}/db.txt" CAKE_REPO_DB)
      file(READ "${CAKE_PKG_REPOS_DIR}/db_next_pk.txt" CAKE_REPO_DB_NEXT_PK)
      set(CAKE_REPO_DB "${CAKE_REPO_DB}" CACHE INTERNAL "" FORCE)
      set(CAKE_REPO_DB_NEXT_PK "${CAKE_REPO_DB_NEXT_PK}" CACHE INTERNAL "" FORCE)
    else()
      set(CAKE_REPO_DB "" CACHE INTERNAL "" FORCE)
      set(CAKE_REPO_DB_NEXT_PK 1 CACHE INTERNAL "" FORCE) # next (first) primary key which must be nonzero
      cake_repo_db_save()
    endif()
  endmacro()

  macro(cake_repo_db_get_pk_by_field field_name field_value)
    if(CAKE_REPO_DB MATCHES "\t([0-9]+)${field_name}=${field_value}(\t|$)")
      set(ans "${CMAKE_MATCH_1}")
    else()
      set(ans "")
    endif()
  endmacro()

  macro(cake_repo_db_get_field_by_pk field pk)
    if(CAKE_REPO_DB MATCHES "\t${pk}${field}=([^\t]*)")
      set(ans "${CMAKE_MATCH_1}")
    else()
      set(ans "")
    endif()
  endmacro()

  macro(cake_repo_db_erase_by_pk pk)
    string(REGEX REPLACE "\t${pk}[^0-9][^\t]+" "" CAKE_REPO_DB "${CAKE_REPO_DB}")
    set(CAKE_REPO_DB "${CAKE_REPO_DB}" CACHE INTERNAL "" FORCE)
    cake_repo_db_save_db()
  endmacro()

  macro(cake_repo_db_next_pk)
    set(ans "${CAKE_REPO_DB_NEXT_PK}")
    math(EXPR CAKE_REPO_DB_NEXT_PK "${CAKE_REPO_DB_NEXT_PK}+1")
    set(CAKE_REPO_DB_NEXT_PK "${CAKE_REPO_DB_NEXT_PK}" CACHE INTERNAL "" FORCE)
    cake_repo_db_save_next_pk()
  endmacro()

  # cake_repo_db_add_fields(pk field1 value1 field2 value2...)
  # where values can be lists (quoted, of course)
  function(cake_repo_db_add_fields pk)
    set(i 1)
    while(i LESS ARGC)
      math(EXPR i_plus_one "${i}+1")
      set(CAKE_REPO_DB "${CAKE_REPO_DB}\t${pk}${ARGV${i}}=${ARGV${i_plus_one}}")
      math(EXPR i "${i}+2")
    endwhile()
    set(CAKE_REPO_DB "${CAKE_REPO_DB}" CACHE INTERNAL "" FORCE)
    cake_repo_db_save_db()
  endfunction()

  # cake_repo_db_add_row(field1 value1 field2 value2)
  # where values can be lists (quoted, of course)
  function(cake_repo_db_add_row)
    cake_repo_db_next_pk()
    set(pk "${ans}")
    # here we must repeat the entire cake_repo_db_add_fields
    # because we accept quoted lists as single (value) arguments
    # which can't be forwarded
    set(i 0)
    while(i LESS ARGC)
      math(EXPR i_plus_one "${i}+1")
      set(CAKE_REPO_DB "${CAKE_REPO_DB}\t${pk}${ARGV${i}}=${ARGV${i_plus_one}}")
      math(EXPR i "${i}+2")
    endwhile()
    set(CAKE_REPO_DB "${CAKE_REPO_DB}" CACHE INTERNAL "" FORCE)
    cake_repo_db_save_db()
  endfunction()

  cake_repo_db_load()

endif()
