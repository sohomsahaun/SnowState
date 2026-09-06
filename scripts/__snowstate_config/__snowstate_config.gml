// SnowState Configuration v4.0.0-alpha

// When true, SnowState assumes the names are strings
// Set it to false if you plan to use non-string state names
#macro SNOWSTATE_ASSUME_STRING_NAMES true

// Verify the type and value of arguments (recommended: true)
#macro SNOWSTATE_VERIFY_USER_ARGS false

// Checks for non-existent states (recommended: true)
#macro SNOWSTATE_CHECK_NON_EXISTENT_STATE true

// Checks for circular inheritance (recommended: true)
#macro SNOWSTATE_CHECK_CIRCULAR_INHERITANCE true

// Show warnings (recommended: true)
#macro SNOWSTATE_SHOW_WARNING true

// Default transition names
#macro SNOWSTATE_WILDCARD_TRANSITION_NAME "*"
#macro SNOWSTATE_REFLEXIVE_TRANSITION_NAME "="

// Default event names
#macro SNOWSTATE_EVENT_ENTER "enter"
#macro SNOWSTATE_EVENT_EXIT "exit"
#macro SNOWSTATE_EVENT_STEP "step"
#macro SNOWSTATE_EVENT_SUSPEND "suspend"
#macro SNOWSTATE_EVENT_RESUME "resume"

// Default history size
#macro SNOWSTATE_DEFAULT_HISTORY_MAX_SIZE 5