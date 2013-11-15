add_subdirectory("A_Grand_Day_Out")
add_subdirectory("A_Space_Adventure")

file(GLOB Scripts *.lua)

install(FILES
    ${Scripts}
    DESTINATION ${SHAREPATH}Data/Missions/Campaign)
