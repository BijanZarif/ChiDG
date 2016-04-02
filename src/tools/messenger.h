use messenger

#define FATAL 3
#define NONFATAL 2
#define WARN 1
#define MSG 0





#define chidg_signal(isig, imsg)                                        message(__FILE__, __LINE__, isig, imsg)
#define chidg_signal_one(isig, imsg, info_one)                          message(__FILE__, __LINE__, isig, imsg, info_one)
#define chidg_signal_two(isig, imsg, info_one, info_two)                message(__FILE__, __LINE__, isig, imsg, info_one, info_two)
#define chidg_signal_three(isig, imsg, info_one, info_two, info_three)  message(__FILE__, __LINE__, isig, imsg, info_one, info_two, info_three)


#define AllocationError  message(__FILE__, __LINE__, FATAL, "Memory allocation error.")


