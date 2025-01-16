using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories.Interfaces
{
    public interface ILicenseRepository
    {
        Models.Licenses.License GetLicenseByType(string licenseType);
    }
}
