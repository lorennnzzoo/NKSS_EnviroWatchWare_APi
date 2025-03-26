using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    //[Authorize(Roles = "Demo")]
    [RoutePrefix("License")]
    public class LicenseController : ApiController
    {
        private readonly LicenseService license_service;
        private Helpers.Validator validator = new Helpers.Validator();
        public LicenseController(LicenseService _license_service)
        {
            this.license_service = _license_service;
        }

        [HttpPost]
        [Route("Register")]
        public IHttpActionResult GenerateLicense(Models.Licenses.Registration registration)
        {
            try
            {
                if (registration.ExpiresAt == null)
                {
                    throw new ArgumentNullException("ExpiryDate is required");
                }
                if (DateTime.Now > registration.ExpiresAt.Value)
                {
                    throw new InvalidOperationException("ExpiryDate Should be in future");
                }

                license_service.GenerateLicenseSoftrack(registration);
                return Ok();
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }            
        }

        [HttpGet]
        [Route("GetCompanyNameById")]
        public IHttpActionResult GetCompanyName(int id)
        {
            try
            {
                string name = license_service.GetCompanyNameSoftrack(id);
                return Ok(name);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }
        //[HttpGet]
        //[Route("GetLicense")]
        //public IHttpActionResult Get(string type)
        //{
        //    try
        //    {
        //        var license = license_service.GetLicenseResponseByType(type);
        //        if (license == null)
        //            return NotFound();
        //        return Ok(license);
        //    }
        //    catch (Exception ex)
        //    {
        //        var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
        //        {
        //            Content = new StringContent(ex.Message)
        //        };

        //        return ResponseMessage(response);
        //    }
        //}

        //[HttpPut]
        //[Route("UpdateLicense")]
        //public IHttpActionResult Update(Models.Licenses.License license)
        //{
        //    try
        //    {
        //        //if (channel == null)
        //        //    return BadRequest("Invalid data.");
        //        var result = validator.ValidateProperties(license);
        //        if (!result.isValid)
        //        {
        //            return BadRequest(result.errorMessage);
        //        }

        //        license_service.Update(license);
        //        return Ok();
        //    }
        //    catch (Exception ex)
        //    {
        //        var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
        //        {
        //            Content = new StringContent(ex.Message)
        //        };

        //        return ResponseMessage(response);
        //    }
        //}
    }
}
