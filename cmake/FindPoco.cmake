# Poco ships two build systems. Its CMake build installs a config package; its classic
# configure/make build installs headers and libPoco*.so and nothing else. A desktop
# distribution uses the first, a Buildroot sysroot the second - so find_package(Poco CONFIG)
# resolves on the machine where it is never exercised and fails on the board.
#
# Components map to libPoco<Component>; NetSSL_OpenSSL builds libPocoNetSSL.

include(FindPackageHandleStandardArgs)

find_path(Poco_INCLUDE_DIR NAMES Poco/Foundation.h)

# Foundation underpins everything and NetSSL pulls Crypto, Util and Net at link time.
# Resolving that closure here keeps the caller's component list the list of things it
# actually includes, rather than the list its linker turns out to need.
set(_poco_components ${Poco_FIND_COMPONENTS} Foundation)
if(NetSSL IN_LIST _poco_components)
	list(APPEND _poco_components Crypto Util Net)
endif()
list(REMOVE_DUPLICATES _poco_components)

foreach(comp IN LISTS _poco_components)
	find_library(Poco_${comp}_LIBRARY NAMES Poco${comp})
	mark_as_advanced(Poco_${comp}_LIBRARY)
	if(Poco_INCLUDE_DIR AND Poco_${comp}_LIBRARY)
		set(Poco_${comp}_FOUND TRUE)
		if(NOT TARGET Poco::${comp})
			# UNKNOWN rather than SHARED: the same module has to serve a sysroot built
			# with BR2_STATIC_LIBS, where these are .a files.
			add_library(Poco::${comp} UNKNOWN IMPORTED)
			set_target_properties(Poco::${comp} PROPERTIES
				IMPORTED_LOCATION "${Poco_${comp}_LIBRARY}"
				INTERFACE_INCLUDE_DIRECTORIES "${Poco_INCLUDE_DIR}")
		endif()
	else()
		set(Poco_${comp}_FOUND FALSE)
	endif()
endforeach()

foreach(comp IN LISTS _poco_components)
	if(TARGET Poco::${comp} AND NOT comp STREQUAL Foundation)
		set_property(TARGET Poco::${comp} APPEND
			PROPERTY INTERFACE_LINK_LIBRARIES Poco::Foundation)
	endif()
endforeach()

if(TARGET Poco::NetSSL)
	set_property(TARGET Poco::NetSSL APPEND
		PROPERTY INTERFACE_LINK_LIBRARIES Poco::Net Poco::Crypto Poco::Util)
endif()

find_package_handle_standard_args(Poco
	REQUIRED_VARS Poco_INCLUDE_DIR Poco_Foundation_LIBRARY
	HANDLE_COMPONENTS)

mark_as_advanced(Poco_INCLUDE_DIR)
unset(_poco_components)
