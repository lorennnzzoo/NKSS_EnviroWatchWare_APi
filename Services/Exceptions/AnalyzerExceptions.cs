using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Exceptions
{
    public class AnalyzerCannotBeDeletedException:Exception
    {
        public AnalyzerCannotBeDeletedException(string analyzer, string channels) : base($"Cannot Delete analyzer : {analyzer} that is connected to channel's : {channels}")
        {

        }
    }
}
