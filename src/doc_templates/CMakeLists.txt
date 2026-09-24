cmake_minimum_required(VERSION 2.8)
cmake_policy(SET CMP0063 NEW)
cmake_policy(SET CMP0054 OLD)

project(ginanDocs)

find_package(Doxygen)
if(DOXYGEN_FOUND)
	set(DOXYGEN_IN		../doc_templates/Doxyfile.in)
	set(DOXYGEN_OUT		Doxyfile)
	set(DOXYGEN_LAYIN	../doc_templates/DoxygenLayout.xml.in)
	set(DOXYGEN_LAYOUT	DoxygenLayout.xml)
	add_custom_target(docs
		ALL
		COMMAND	${CMAKE_COMMAND} -DIN=${DOXYGEN_IN} -DOUT=${DOXYGEN_OUT} -P "../cmake/Configure.cmake"
		COMMAND ${CMAKE_COMMAND} -DIN=${DOXYGEN_LAYIN} -DOUT=${DOXYGEN_LAYOUT} -P "../cmake/Configure.cmake"
		COMMAND ${DOXYGEN_EXECUTABLE} ${CMAKE_CURRENT_BINARY_DIR}/${DOXYGEN_OUT}
		# WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../build
		COMMENT "Generating API documentation with Doxygen"
		VERBATIM)

	list(APPEND CTEST_CUSTOM_WARNING_EXCEPTION
	".*warning: ignoring loop annotation.*"
	".*warning: .*Consider increasing DOT_GRAPH_MAX_NODES."
	)

else()
	message("Doxygen not found")
endif()
add_subdirectory(../cpp ./cpp)
