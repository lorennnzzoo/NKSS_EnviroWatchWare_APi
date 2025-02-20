using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Exceptions
{
    public class LicenseTypeAlreadyExistsException : Exception
    {
        public LicenseTypeAlreadyExistsException(string type)
           : base($"A License with the type '{type}' already exists.")
        {
        }
    }
    public class LicenseNotFoundException : Exception
    {
        public LicenseNotFoundException()
           : base($"WatchWare License not found.")
        {
        }
    }

    public class KeyExpiredException : Exception
    {
        public KeyExpiredException()
           : base($"Provided key is expired.")
        {
        }
    }
    public class InvalidKeyException : Exception
    {
        public InvalidKeyException()
           : base($"Provided key is invalid.")
        {
        }
    }
}
