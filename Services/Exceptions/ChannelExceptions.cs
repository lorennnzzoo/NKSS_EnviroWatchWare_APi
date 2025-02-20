using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Exceptions
{
    public class ChannelWithSameNameExists:Exception
    {
        public ChannelWithSameNameExists(string channel, string station) : base($"Channel with name : {channel} already exists in station : {station}")
        {

        }
    }
}
