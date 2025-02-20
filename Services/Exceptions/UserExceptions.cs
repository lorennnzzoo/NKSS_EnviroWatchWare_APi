using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Exceptions
{
    public class UserAlreadyExistsException : Exception
    {
        public UserAlreadyExistsException(string username)
           : base($"A user with the username '{username}' already exists.")
        {
        }
    }

    public class PhoneNumberTooLongException : Exception
    {
        public PhoneNumberTooLongException(string phoneNumber)
            : base($"The phone number '{phoneNumber}' is too long. Maximum allowed length is 10.")
        {
        }
    }


    public class CannotDeactivateTheLoggedInUser:Exception
    {
        public CannotDeactivateTheLoggedInUser()
            : base($"Cannot deactivate your own account")
        {
        }
    }

    public class AdministratorAccountAlreadyExistsException : Exception
    {
        public AdministratorAccountAlreadyExistsException()
            : base($"Cannot create more than one administrator account.")
        {
        }
    }

    public class CannotUseReservedUsernameException : Exception
    {
        public CannotUseReservedUsernameException(string username)
            : base($"Cannot create account with username : {username}, It is reserved.")
        {
        }
    }
}
