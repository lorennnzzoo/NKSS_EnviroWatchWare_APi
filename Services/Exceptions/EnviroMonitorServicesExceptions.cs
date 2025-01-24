using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Exceptions
{
    public class NoRecordsFoundForGroupNameException : Exception
    {
        public NoRecordsFoundForGroupNameException(string groupName) : base($"No records found for group : {groupName} in Config Settings")
        {

        }
    }
}
