get_target_property (QtCore_location Qt6::Core LOCATION)
get_filename_component (QtCore_location ${QtCore_location} PATH)
list (APPEND fixup_library_dirs ${QtCore_location})

if (APPLE OR WIN32)
  # install rules for including 3rd party libs such as Qt

  # install a qt.conf file
  install (CODE "
        get_filename_component (the_qt_conf \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${WSJT_QT_CONF_DESTINATION}/qt.conf\" REALPATH)
        file (WRITE \"\${the_qt_conf}\"
\"[Paths]
\")
"
    #COMPONENT runtime
    )

  # if a system Qt is used (e.g. installed in /usr/lib/), it will not be included in the installation
  set (fixup_exe "\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}/${CMAKE_PROJECT_NAME}${CMAKE_EXECUTABLE_SUFFIX}")

  #get_filename_component (hamlib_lib_dir ${Hamlib_LIBRARIES} PATH)

  if (APPLE)
    # Homebrew Qt may expose plugin directories as symlinks below /opt/homebrew/share/qt/plugins.
    # install(DIRECTORY ...) preserves those links and can create broken links inside the .app.
    # Therefore install the real plugin files explicitly.
    if (NOT QT_PLUGINS_DIR OR NOT EXISTS "${QT_PLUGINS_DIR}")
      if (EXISTS "/opt/homebrew/share/qt/plugins")
        set (QT_PLUGINS_DIR "/opt/homebrew/share/qt/plugins")
      elseif (EXISTS "/opt/homebrew/opt/qt/share/qt/plugins")
        set (QT_PLUGINS_DIR "/opt/homebrew/opt/qt/share/qt/plugins")
      endif ()
    endif ()

    message (STATUS "Using Qt plugin directory: ${QT_PLUGINS_DIR}")

    set (_wsjt_qt_plugin_dirs
      platforms
      audio
      accessible
      imageformats
      styles
      tls
      iconengines
      multimedia
      sqldrivers
      )

    foreach (_wsjt_plugin_dir IN LISTS _wsjt_qt_plugin_dirs)
      if (EXISTS "${QT_PLUGINS_DIR}/${_wsjt_plugin_dir}")
        file (GLOB _wsjt_plugin_files
          "${QT_PLUGINS_DIR}/${_wsjt_plugin_dir}/*${CMAKE_SHARED_LIBRARY_SUFFIX}"
          )
        foreach (_wsjt_plugin IN LISTS _wsjt_plugin_files)
          get_filename_component (_wsjt_plugin_name "${_wsjt_plugin}" NAME)
          if (_wsjt_plugin_name MATCHES "minimal.*${CMAKE_SHARED_LIBRARY_SUFFIX}$")
            continue ()
          endif ()
          if (_wsjt_plugin_name MATCHES "offscreen.*${CMAKE_SHARED_LIBRARY_SUFFIX}$")
            continue ()
          endif ()
          if (_wsjt_plugin_name MATCHES "quick.*${CMAKE_SHARED_LIBRARY_SUFFIX}$")
            continue ()
          endif ()
          if (_wsjt_plugin_name MATCHES "webgl.*${CMAKE_SHARED_LIBRARY_SUFFIX}$")
            continue ()
          endif ()
          if (_wsjt_plugin_name MATCHES "_debug${CMAKE_SHARED_LIBRARY_SUFFIX}$")
            continue ()
          endif ()

          get_filename_component (_wsjt_plugin_real "${_wsjt_plugin}" REALPATH)
          if (EXISTS "${_wsjt_plugin_real}")
            install (
              FILES "${_wsjt_plugin_real}"
              DESTINATION "${WSJT_PLUGIN_DESTINATION}/${_wsjt_plugin_dir}"
              CONFIGURATIONS Release MinSizeRel RelWithDebInfo
              #COMPONENT runtime
              )
          endif ()
        endforeach ()
        unset (_wsjt_plugin_files)
      endif ()
    endforeach ()

    # add plugins path for Mac Bundle
    install (CODE "
          get_filename_component (the_qt_conf \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${WSJT_QT_CONF_DESTINATION}/qt.conf\" REALPATH)
          file (APPEND \"\${the_qt_conf}\"
\"Plugins = PlugIns
\")
"
      #COMPONENT runtime
      )

    list (APPEND fixup_library_dirs
      "/opt/homebrew/opt/qt/lib"
      "/opt/homebrew/lib"
      "/opt/local/jtdxhamlib/lib"
      )

    foreach (_wsjt_gcc_runtime_dir
      "/opt/homebrew/opt/gcc/lib/gcc/current"
      "/opt/homebrew/lib/gcc/current"
      )
      if (EXISTS "${_wsjt_gcc_runtime_dir}")
        list (APPEND fixup_library_dirs "${_wsjt_gcc_runtime_dir}")
      endif ()
    endforeach ()

    find_library (WSJT_GFORTRAN_LIBRARY
      NAMES gfortran.5 gfortran
      PATHS
        "/opt/homebrew/opt/gcc/lib/gcc/current"
        "/opt/homebrew/lib/gcc/current"
      NO_DEFAULT_PATH
      )
    find_library (WSJT_QUADMATH_LIBRARY
      NAMES quadmath.0 quadmath
      PATHS
        "/opt/homebrew/opt/gcc/lib/gcc/current"
        "/opt/homebrew/lib/gcc/current"
      NO_DEFAULT_PATH
      )
    find_library (WSJT_GCC_S_LIBRARY
      NAMES gcc_s.1.1 gcc_s
      PATHS
        "/opt/homebrew/opt/gcc/lib/gcc/current"
        "/opt/homebrew/lib/gcc/current"
      NO_DEFAULT_PATH
      )

    set (WSJT_APPLE_EXTRA_LIBS "")
    set (WSJT_APPLE_GP_MAP "")

    # BundleUtilities requires additional libraries passed in the "libs" argument
    # to already live inside the bundle.  Do not pass Homebrew GCC runtime
    # libraries by their external /opt/homebrew path; install them into
    # Contents/Frameworks first and pass the bundled paths to fixup_bundle().
    foreach (_wsjt_runtime_lib IN ITEMS
      "${WSJT_GFORTRAN_LIBRARY}"
      "${WSJT_QUADMATH_LIBRARY}"
      "${WSJT_GCC_S_LIBRARY}"
      )
      if (_wsjt_runtime_lib AND NOT _wsjt_runtime_lib MATCHES "-NOTFOUND$" AND EXISTS "${_wsjt_runtime_lib}")
        get_filename_component (_wsjt_runtime_name "${_wsjt_runtime_lib}" NAME)

        install (
          FILES "${_wsjt_runtime_lib}"
          DESTINATION "${CMAKE_INSTALL_BINDIR}/../Frameworks"
          CONFIGURATIONS Release MinSizeRel RelWithDebInfo
          #COMPONENT runtime
          )

        # The final bundle path is resolved inside the install(CODE) block.
        # Do not pass configure-time paths with DESTDIR or Contents/MacOS/..
        # to fixup_bundle(), because BundleUtilities may reject them as not
        # being inside the bundle.
      endif ()
    endforeach ()

    message (STATUS "Apple fixup library dirs: ${fixup_library_dirs}")
    message (STATUS "Apple extra runtime libs: ${WSJT_APPLE_EXTRA_LIBS}")
  endif (APPLE)

  if (WIN32)
    # DLL directories
    get_filename_component (hamlib_lib_dir ${Hamlib_LIBRARY} PATH)
    list (APPEND fixup_library_dirs ${hamlib_lib_dir}/../bin)

    get_filename_component (usb_lib_dir ${Usb_LIBRARY} PATH)
    list (APPEND fixup_library_dirs ${usb_lib_dir})

    get_filename_component (portaudio_lib_dir ${Portaudio_LIBRARY} PATH)
    list (APPEND fixup_library_dirs ${portaudio_lib_dir}/../bin)

    get_filename_component (fftw_lib_dir ${FFTW3F_LIBRARY} PATH)
    list (APPEND fixup_library_dirs ${fftw_lib_dir})

    # install required Qt plugins
    install (
      DIRECTORY
      ${QT_PLUGINS_DIR}/platforms
      ${QT_PLUGINS_DIR}/styles
      ${QT_PLUGINS_DIR}/accessible
      ${QT_PLUGINS_DIR}/audio
      ${QT_PLUGINS_DIR}/imageformats
      DESTINATION ${WSJT_PLUGIN_DESTINATION}
      CONFIGURATIONS Release MinSizeRel RelWithDebInfo
      #COMPONENT runtime
      FILES_MATCHING PATTERN "*${CMAKE_SHARED_LIBRARY_SUFFIX}"
      PATTERN "*minimal*${CMAKE_SHARED_LIBRARY_SUFFIX}" EXCLUDE
      PATTERN "*offscreen*${CMAKE_SHARED_LIBRARY_SUFFIX}" EXCLUDE
      PATTERN "*quick*${CMAKE_SHARED_LIBRARY_SUFFIX}" EXCLUDE
      PATTERN "*d${CMAKE_SHARED_LIBRARY_SUFFIX}" EXCLUDE
      )
    install (
      FILES
      ${QT_PLUGINS_DIR}/sqldrivers/qsqlite${CMAKE_SHARED_LIBRARY_SUFFIX}
      DESTINATION ${WSJT_PLUGIN_DESTINATION}/sqldrivers
      CONFIGURATIONS Release MinSizeRel RelWithDebInfo
      #COMPONENT runtime
      )
    # install (
    # 	DIRECTORY
    # 	${QT_PLUGINS_DIR}/platforms
    # 	${QT_PLUGINS_DIR}/accessible
    # 	${QT_PLUGINS_DIR}/audio
    # 	DESTINATION ${WSJT_PLUGIN_DESTINATION}
    # 	CONFIGURATIONS Debug
    # 	#COMPONENT runtime
    # 	FILES_MATCHING PATTERN "*d${CMAKE_SHARED_LIBRARY_SUFFIX}"
    # 	PATTERN "*minimal*${CMAKE_SHARED_LIBRARY_SUFFIX}" EXCLUDE
    # 	PATTERN "*offscreen*${CMAKE_SHARED_LIBRARY_SUFFIX}" EXCLUDE
    # 	PATTERN "*quick*${CMAKE_SHARED_LIBRARY_SUFFIX}" EXCLUDE
    # 	)

    # add paths for WIN32
    file (RELATIVE_PATH _plugins_path "${CMAKE_INSTALL_PREFIX}/${WSJT_QT_CONF_DESTINATION}" "${CMAKE_INSTALL_PREFIX}/${WSJT_PLUGIN_DESTINATION}")
    install (CODE "
        get_filename_component (the_qt_conf \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${WSJT_QT_CONF_DESTINATION}/qt.conf\" REALPATH)
        file (APPEND \"\${the_qt_conf}\"
\"Plugins = ${_plugins_path}
\")
"
      #COMPONENT runtime
      )

    set (gp_tool "objdump")	# we want MinGW tool - not MSVC (See GetPrerequisites.cmake)

    # --- 1) Discover msys-2.0.dll (dynamic, no hard-coding) ---
    find_file(MSYS_DLL
      NAMES msys-2.0.dll
      PATHS
        "${JTSDK_TOOLS_ROOT}/msys64/usr/bin"
        $ENV{MSYS_ROOT}/usr/bin
        $ENV{MSYS2_PATH}/usr/bin
      NO_DEFAULT_PATH
    )

    if (MSYS_DLL AND NOT MSYS_DLL STREQUAL "MSYS_DLL-NOTFOUND")
      message(STATUS "Found msys-2.0.dll at: ${MSYS_DLL}")
    else()
      message(WARNING "msys-2.0.dll not found under JTSDK tools; MAP65 may not run without it")
      message(STATUS "JTSDK_TOOLS_ROOT is: ${JTSDK_TOOLS_ROOT}")
    endif()

    # --- 2) Install msys-2.0.dll explicitly into bin (belt-and-suspenders) ---
    if (MSYS_DLL AND NOT MSYS_DLL STREQUAL "MSYS_DLL-NOTFOUND")
      install(FILES "${MSYS_DLL}" DESTINATION ${CMAKE_INSTALL_BINDIR})
      message(STATUS "msys-2.0.dll copied explicitly to ${CMAKE_INSTALL_BINDIR}")
    endif()

    # --- 3) Help fixup_bundle resolve names, and include msys bin in search dirs ---
    set(GP_ITEM_GLOBAL_MAP "msys-2.0.dll=${MSYS_DLL}")
    list(APPEND fixup_library_dirs
      "${JTSDK_TOOLS_ROOT}/msys64/usr/bin"
    )
  endif (WIN32)

  # --- 4) Run fixup_bundle ---
  INSTALL (CODE "
    get_filename_component (the_path \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${WSJT_PLUGIN_DESTINATION}\" REALPATH)
    file (GLOB_RECURSE QTPLUGINS \"\${the_path}/*${CMAKE_SHARED_LIBRARY_SUFFIX}\")

    include (BundleUtilities)
    set (BU_CHMOD_BUNDLE_ITEMS ON)
    set (GP_ITEM_GLOBAL_MAP \"${GP_ITEM_GLOBAL_MAP}\")
    set (gp_tool ${gp_tool})
    get_filename_component (the_exe ${fixup_exe} REALPATH)

    if (WIN32)
      if (\"${MSYS_DLL}\" STREQUAL \"MSYS_DLL-NOTFOUND\" OR \"${MSYS_DLL}\" STREQUAL \"\")
        set(extra_libs \"\")
        message(STATUS \"Skipping msys-2.0.dll: not found\")
      else()
        set(extra_libs \"${MSYS_DLL}\")
        message(STATUS \"Including msys-2.0.dll in fixup_bundle: ${MSYS_DLL}\")
      endif()
      set(ignore_items \"msys-2.0.dll\")
    elseif (APPLE)
      set(extra_libs \"\")
      set(ignore_items \"\")
      set(_wsjt_bundle_frameworks \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}/../Frameworks\")
      get_filename_component(_wsjt_bundle_frameworks \"\${_wsjt_bundle_frameworks}\" REALPATH)

      foreach(_wsjt_runtime_name IN ITEMS
        libgfortran.5.dylib
        libquadmath.0.dylib
        libgcc_s.1.1.dylib
      )
        if(EXISTS \"\${_wsjt_bundle_frameworks}/\${_wsjt_runtime_name}\")
          list(APPEND extra_libs \"\${_wsjt_bundle_frameworks}/\${_wsjt_runtime_name}\")
          list(APPEND GP_ITEM_GLOBAL_MAP
            \"@rpath/\${_wsjt_runtime_name}=\${_wsjt_bundle_frameworks}/\${_wsjt_runtime_name}\"
            \"\${_wsjt_runtime_name}=\${_wsjt_bundle_frameworks}/\${_wsjt_runtime_name}\"
          )
        endif()
      endforeach()
    else()
      set(extra_libs \"\")
      set(ignore_items \"\")
    endif()

    fixup_bundle (\"\${the_exe}\" \"\${QTPLUGINS};\${extra_libs}\" \"${fixup_library_dirs}\" IGNORE_ITEM \${ignore_items})

    if (WIN32 AND EXISTS \"${MSYS_DLL}\")
      set(_bundle_bin \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}\")
      if (EXISTS \"\${_bundle_bin}\")
        file(COPY \"${MSYS_DLL}\" DESTINATION \"\${_bundle_bin}\")
        message(STATUS \"msys-2.0.dll copied explicitly to \${_bundle_bin}\")
      endif()
    endif()
"
)
endif (APPLE OR WIN32)
