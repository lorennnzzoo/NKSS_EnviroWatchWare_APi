using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Exceptions
{
    public class OxideCannotBeDeletedException:Exception
    {
        public OxideCannotBeDeletedException(string oxide,string channels):base($"Cannot Delete oxide : {oxide} that is connected to channel's : {channels}")
        {

        }
    }
}
