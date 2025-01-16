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
}
