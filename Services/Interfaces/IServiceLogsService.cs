using Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface IServiceLogsService
    {
        IEnumerable<ServiceLogs> Get24HourLogsByType(string Type);
        IEnumerable<string> GetTypes();
        IEnumerable<ServiceLogs> GetLastMinuteLogsByType(string Type);
    }
}
