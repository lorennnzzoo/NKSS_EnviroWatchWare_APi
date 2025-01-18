using Models;
using Post = Models.Post;
using Services;
using System;
using System.Web.Http;
using System.Net.Http;
using System.Net;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize]
    [RoutePrefix("Company")]
    public class CompanyController : ApiController
    {
        private readonly CompanyService company_service;
        private Helpers.Validator validator = new Helpers.Validator();
        private Helpers.CompanyValidator companyValidator = new Helpers.CompanyValidator();
        public CompanyController(CompanyService _company_service)
        {
            this.company_service = _company_service;
        }


        [HttpGet]
        [Route("GetCompany")]
        public IHttpActionResult Get(int id)
        {
            try
            {
                var company = company_service.GetCompanyById(id);
                if (company == null)
                    return NotFound();
                return Ok(company);
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetAllCompanies")]
        public IHttpActionResult GetAll()
        {
            try
            {
                var companies = company_service.GetAllCompanies();
                return Ok(companies);
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpPost]
        [Route("AddCompany")]
        public IHttpActionResult Add(Post.Company company)
        {
            try
            {
                //if (company == null)
                //    return BadRequest("Invalid data.");
                var result= companyValidator.ValidateProperties(company);
                if (!result.isValid)
                {
                    return BadRequest(result.errorMessage);
                }

                company_service.CreateCompany(company);
                return Ok();
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpPut]
        [Route("UpdateCompany")]
        public IHttpActionResult Update(Models.Put.Company company)
        {
            try
            {
                var result = companyValidator.ValidateProperties(company);
                if (!result.isValid)
                {
                    return BadRequest(result.errorMessage);
                }

                company_service.UpdateCompany(company);
                return Ok();
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpDelete]
        [Route("DeleteCompany")]
        public IHttpActionResult Delete(int id)
        {
            try
            {
                company_service.DeleteCompany(id);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }
    }
}
