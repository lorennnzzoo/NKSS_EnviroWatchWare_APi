using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Protocol
{
    public class Mapper
    {
        public static Dictionary<string, Func<Models.Analyzer,Models.Channel,decimal?>> ProtocolDictionary = new Dictionary<string, Func<Models.Analyzer, Models.Channel, decimal?>>
        {
            { "RS485INTEGER", Methods.GetDataFromRS485Integer }
        };
    }
}
