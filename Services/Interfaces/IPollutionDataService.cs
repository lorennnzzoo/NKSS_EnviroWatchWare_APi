using Models.PollutionData;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface IPollutionDataService
    {        
        bool ValidateDataIntegrity(string apiKey,PollutantDataUploadRequest request);

        bool ImportData(string apiKey, PollutantDataUploadRequest request);
    }
}
