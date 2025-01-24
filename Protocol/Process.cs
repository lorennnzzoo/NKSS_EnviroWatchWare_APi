using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Protocol
{
    public class Process
    {
        public static decimal? FetchAnalyzerValue(Models.Analyzer analyzer,Models.Channel channel)
        {
            decimal? value = null;
            if (Mapper.ProtocolDictionary.TryGetValue(analyzer.ProtocolType, out var method))
            {
                // Call the method and capture the result
                value = method(analyzer,channel);
            }
            else
            {
                
            }
            return value;
        }
    }
}
