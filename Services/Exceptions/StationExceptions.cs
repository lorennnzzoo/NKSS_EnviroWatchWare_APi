using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Exceptions
{
    public class StationWithSameNameExists:Exception
    {
        public StationWithSameNameExists(string station, string company) : base($"Station with name : {station} already exists in company : {company}")
        {

        }
    }
}
