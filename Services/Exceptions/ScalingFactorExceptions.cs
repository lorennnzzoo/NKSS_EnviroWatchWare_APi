using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Exceptions
{
    public class ScalingFactorCannotBeDeletedException:Exception
    {
        public ScalingFactorCannotBeDeletedException(string channels) : base($"Cannot Delete scaling factor that is connected to channel's : {channels}")
        {

        }
    }
}
